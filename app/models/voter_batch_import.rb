# encoding: UTF-8

class VoterBatchImport
  attr_reader :list, :csv_to_system_map, :csv_headers, :voters_list, :result, :csv_phone_column_location,
              :csv_custom_id_column_location, :custom_attributes, :blocked_numbers, :campaign

  def initialize(list, csv_to_system_map, csv_headers, csv_data)
    @list              = list
    @campaign          = list.campaign
    @blocked_numbers   = campaign.blocked_numbers
    @csv_to_system_map = csv_to_system_map
    @csv_headers       = csv_headers.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
    @voters_list       = csv_data
    @result            = {:success => 0, :failed => 0, :dnc => 0, :cell => 0}
    @csv_to_system_map.remap_system_column! "ID", :to => "custom_id"
    
    @csv_phone_column_location     = @csv_headers.index(@csv_to_system_map.csv_index_for "phone")
    @csv_custom_id_column_location = @csv_headers.index(@csv_to_system_map.csv_index_for "custom_id")
    @custom_attributes             = create_custom_attributes
  end

  # return true when desirable to not import numbers for cell devices
  # return false when desirable to import numbers for both cell & landline devices
  def skip_wireless?
    @list.skip_wireless?
  end

  def dnc_wireless
    @dnc_wireless ||= DoNotCall::WirelessList.new
  end

  def calculate_blocked(phone)
    blocked = []
    if skip_wireless? && dnc_wireless.prohibits?(phone)
      blocked << :cell
    end
    if blocked_numbers.include?(phone)
      blocked << :dnc
    end
    blocked
  end

  # build & validate new households
  def build_household(phone)
    unless PhoneNumber.valid?(phone)
      return nil
    end

    household           = {
      account_id: campaign.account_id,
      campaign_id: campaign.id,
      phone: phone
    }

    household[:blocked] = Household.bitmask_for_blocked( *calculate_blocked(phone) )

    return household
  end

  # don't validate existing households, just update blocked bits
  def update_household(id, phone, campaign)
    household = {
      id:          id,
      campaign_id: campaign.id,
      account_id:  campaign.account_id,
      phone:       phone,
      blocked:     Household.bitmask_for_blocked( *calculate_blocked(phone) )
    }

    return household
  end

  def create_or_update_households(rows)
    source = 'voter_batch_import.create_or_update_households'
    benchmark = ImpactPlatform::Metrics::Benchmark.new(source)

    phones = nil
    numbers = nil
    benchmark.time('prepare_phone_numbers') do
      phones              = rows.map{ |row| PhoneNumber.new(row[csv_phone_column_location]) }
      numbers             = phones.map(&:to_s)
    end

    households = nil
    benchmark.time('load_households.initial') do
      household_query     = Household.where(campaign_id: campaign.id, phone: numbers).select([:phone, :id])
      households          = load_as_hash(household_query)
    end

    new_households = nil
    new_numbers = nil
    benchmark.time('build_households') do
      new_numbers         = numbers - households.keys
      new_households      = new_numbers.map{|n| build_household(n)}.compact
    end

    existing_households = nil
    benchmark.time('update_households') do    
      existing_households = households.map{|phone, id| update_household(id, phone, campaign) }
    end

    created_households  = {}

    if new_households.any?
      benchmark.time('import_households.new') do
        import_from_hashes(Household, new_households)
      end

      benchmark.time('load_households.created') do
        created_households = load_as_hash(Household.where(campaign_id: campaign.id, phone: new_numbers).select([:phone, :id]))
      end
    end

    if existing_households.any?
      benchmark.time('import_households.existing') do
        import_from_hashes(Household, existing_households)
      end
    end

    households.merge(created_households)
  end

  def import_csv
    source = 'voter_batch_import.import_csv'
    benchmark = ImpactPlatform::Metrics::Benchmark.new(source)

    households_count = 0
    household_ids    = []
    @voters_list.each_slice((ENV['VOTER_BATCH_SIZE'] || 1000).to_i).each do |voter_info_list|
      custom_fields     = []
      leads             = []
      updated_leads     = {}
      successful_voters = []

      households  = create_or_update_households(voter_info_list)
      found_leads = found_voters(voter_info_list) if custom_id_present?
      
      households_count += households.keys.size

    benchmark.time('prepare_voters') do
      voter_info_list.each do |voter_info|
        raw_phone_number = voter_info[@csv_phone_column_location]
        phone_number     = PhoneNumber.sanitize(raw_phone_number)

        lead = nil

        if (not PhoneNumber.valid?(phone_number))
          result[:failed] += 1
          next
        end

        current_household = households[phone_number]
        if current_household.nil?
          result[:failed] += 1
          next
        end

        if custom_id_present?
          custom_id = voter_info[@csv_custom_id_column_location]
          lead_id   = found_leads[custom_id]
          if lead_id.present?
            lead = {
              id: lead_id,
              voter_list_id: @list.id,
              household_id: households[phone_number],
              enabled: Voter.bitmask_for_enabled(:list)
            }
            updated_leads[custom_id] = lead
          end
        end

        lead ||= {
          :voter_list_id => @list.id,
          :household_id  => households[phone_number],
          :account_id    => @list.account_id,
          :campaign_id   => @list.campaign_id,
          :enabled       => Voter.bitmask_for_enabled(:list)
        }

        # persist app-defined field data (address, city, etc)
        @csv_headers.each_with_index do |csv_column_title, column_location|
          system_column = @csv_to_system_map.system_column_for csv_column_title
          value = voter_info[column_location]
          if !system_column.blank? && system_column != "phone"
            if Voter.column_names.include? system_column
              lead[system_column] = value
            end
          end
        end

        blocked = calculate_blocked(phone_number)
        blocked.each{|type| result[type] += 1}
        result[:success] += 1

        leads << lead
        successful_voters << voter_info
      end
    end

    created_voter_ids = nil
    benchmark.time('import_voters') do
      created_voter_ids = created_ids(@list.voters.reorder(:id)) do
        import_from_hashes(Voter, leads)
      end
    end

      household_ids += households.values.sort
      household_ids.uniq!
      
      voter_ids_for_cache = created_voter_ids.dup

      # persist custom field data
    benchmark.time('import_voter_fields') do
      save_field_values(successful_voters, created_voter_ids, updated_leads)
    end

      Resque.enqueue(CallFlow::DialQueue::Jobs::CacheVoters, campaign.id, voter_ids_for_cache, 1)
      if (existing_voter_ids = leads.map{|l| l[:id]}.compact).any?
        Resque.enqueue(CallFlow::DialQueue::Jobs::CacheVoters, campaign.id, existing_voter_ids, 1)
      end
    end
    
    household_ids.each_slice(100) do |ids|
      Resque.enqueue(CallFlow::Jobs::PruneHouseholds, @list.campaign_id, *ids)
    end

    @list.update_column(:households_count, households_count)

    @result
  end

protected

  def found_voters(voter_info_list)
    custom_ids = voter_info_list.map do |voter_info|
      voter_info[@csv_custom_id_column_location]
    end
    query = Voter.where(custom_id: custom_ids, campaign_id: @list.campaign_id).select([:custom_id, :id])
    load_as_hash(query)
  end

  def load_as_hash(query)
    query = query.to_sql unless query.is_a?(String)
    Hash[*OctopusConnection.connection(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)).execute(query).to_a.flatten]
  end

  def created_ids(relation)
    last_id = relation.last.try(:id)
    yield
    last_id ? relation.where("id > #{last_id}").pluck(:id) : relation.pluck(:id)
  end

  def save_field_values(voter_info_list, created_voter_ids, updated_leads)
    updated_ids = updated_leads.values.map { |l| l[:id] }

    query = CustomVoterFieldValue.where(voter_id: updated_ids, custom_voter_field_id: @custom_attributes.values).
      select([:id, :voter_id, :custom_voter_field_id]).to_sql

    custom_field_values = CustomVoterFieldValue.connection.execute(query).each(as: :hash).each_with_object({}) do |data, memo|
      memo[data['voter_id']] ||= {}
      memo[data['voter_id']][data['custom_voter_field_id']] = {id: data['id'], value: data['value']}
    end
    custom_voter_values = []

    voter_info_list.each do |voter_info|
      if custom_id_present? && updated_leads && updated_leads[voter_info[@csv_custom_id_column_location]]
        lead_id = updated_leads[voter_info[@csv_custom_id_column_location]][:id]
      else
        lead_id = created_voter_ids.shift
      end
      @csv_headers.each_with_index do |csv_column_title, column_location|
        system_column    = @csv_to_system_map.system_column_for csv_column_title
        value            = voter_info[column_location]
        custom_attribute = @custom_attributes[system_column]
        if custom_attribute
          custom_field_value = custom_field_values[lead_id][custom_attribute] if custom_field_values[lead_id]
          custom_field_value ||= {}
          custom_field_value[:voter_id] ||= lead_id
          custom_field_value[:custom_voter_field_id] ||= custom_attribute
          custom_field_value[:value] = value
          custom_voter_values << custom_field_value
        end
      end
    end

    import_from_hashes(CustomVoterFieldValue, custom_voter_values)
  end

  def import_from_hashes(klass, hashes)
    klass.import_hashes(hashes)
  end

  def create_custom_attributes
    data = {}
    temp_voter = Voter.new
    @csv_headers.each do |csv_column_title|
      system_column = @csv_to_system_map.system_column_for csv_column_title
      if !system_column.blank? && !(temp_voter.has_attribute? system_column)
        custom_attribute = @list.account.custom_voter_fields.find_by_name(system_column)
        custom_attribute ||= CustomVoterField.create(name: system_column, account: @list.account)
        data[system_column] = custom_attribute.id
      end
    end
    data
  end

  def custom_id_present?
    @csv_custom_id_column_location.present?
  end
end
