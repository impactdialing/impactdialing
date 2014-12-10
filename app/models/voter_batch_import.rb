# encoding: UTF-8
require 'benchmark'
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
  def update_household(id, phone)
    household = {
      id: id,
      blocked: Household.bitmask_for_blocked( *calculate_blocked(phone) )
    }

    return household
  end

  def create_or_update_households(rows)
    phones              = rows.map{ |row| PhoneNumber.new(row[csv_phone_column_location]) }
    numbers             = phones.map(&:to_s)
    household_query     = Household.where(campaign_id: campaign.id, phone: numbers).select([:phone, :id])
    households          = load_as_hash(household_query)
    new_numbers         = numbers - households.keys
    new_households      = new_numbers.map{|n| build_household(n)}.compact
    existing_households = households.map{|phone, id| update_household(id, phone) }
    created_households  = {}

    if new_households.any?    
      Household.import new_households.first.keys, new_households.map(&:values)
      created_households = load_as_hash(Household.where(campaign_id: campaign.id, phone: new_numbers).select([:phone, :id]))
    end

    if existing_households.any?
      Household.import existing_households.first.keys, existing_households.map(&:values), validate: false, on_duplicate_key_update: [:blocked]
    end

    households.merge(created_households)
  end

  def import_csv
    @voters_list.each_slice(1000).each do |voter_info_list|
      custom_fields     = []
      leads             = []
      updated_leads     = {}
      successful_voters = []

      households  = create_or_update_households(voter_info_list)
      found_leads = found_voters(voter_info_list) if custom_id_present?

      voter_info_list.each do |voter_info|
        raw_phone_number = voter_info[@csv_phone_column_location]
        phone_number     = PhoneNumber.sanitize(raw_phone_number)

        lead = nil

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

          elsif (not PhoneNumber.valid?(phone_number))
            result[:failed] += 1
            next
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

      created_voter_ids = created_ids(@list.voters.reorder(:id)) do
        import_from_hashes(Voter, leads)
      end

      # persist custom field data
      save_field_values(successful_voters, created_voter_ids, updated_leads)
    end
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
        system_column = @csv_to_system_map.system_column_for csv_column_title
        value = voter_info[column_location]
        custom_attribute = @custom_attributes[system_column]
        if custom_attribute
          custom_field_value = custom_field_values[lead_id][custom_attribute] if custom_field_values[lead_id]
          custom_field_value ||= {voter_id: lead_id, custom_voter_field_id: custom_attribute}
          custom_voter_values << custom_field_value.merge(value: value)
        end
      end
    end

    import_from_hashes(CustomVoterFieldValue, custom_voter_values)
  end


  def import_from_hashes(klass, hashes)
    return if hashes.empty?
    new_records = {values: []}
    existing_records = {values: []}
    hashes.each do |hash|
      if hash[:id]
        existing_records[:columns] ||= hash.keys
        existing_records[:values] << hash.values
      else
        new_records[:columns] ||= hash.keys
        new_records[:values] << hash.values
      end
    end

    klass.import(existing_records[:columns], existing_records[:values],
                 on_duplicate_key_update: existing_records[:columns],
                 validate: false, timestamps: false) if existing_records[:values].any?
    klass.import(new_records[:columns], new_records[:values]) if new_records[:values].any?
  end


  def create_custom_attributes
    result = {}
    temp_voter = Voter.new
    @csv_headers.each do |csv_column_title|
      system_column = @csv_to_system_map.system_column_for csv_column_title
      if !system_column.blank? && !(temp_voter.has_attribute? system_column)
        custom_attribute = @list.account.custom_voter_fields.find_by_name(system_column)
        custom_attribute ||= CustomVoterField.create(name: system_column, account: @list.account)
        result[system_column] = custom_attribute.id
      end
    end
    result
  end

  def custom_id_present?
    @csv_custom_id_column_location.present?
  end
end
