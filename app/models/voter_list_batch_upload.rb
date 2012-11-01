# encoding: UTF-8
require 'benchmark'
class VoterListBatchUpload

  def initialize(list, csv_to_system_map, csv_filename, separator)
    @list = list
    @csv_to_system_map = csv_to_system_map
    csv = CSV.new(VoterList.read_from_s3(csv_filename).value, :col_sep => separator)
    @csv_headers = csv.shift.collect{|h| h.blank? ? VoterList::BLANK_HEADER : h}
    @voters_list = csv.readlines.shuffle
    @result = {:successCount => 0, :failedCount => 0}
    @csv_to_system_map.remap_system_column! "ID", :to => "CustomID"
    @csv_phone_column_location = @csv_headers.index(@csv_to_system_map.csv_index_for "Phone")    
    @csv_custom_id_column_location = @csv_headers.index(@csv_to_system_map.csv_index_for "CustomID")
    @custom_attributes = create_custom_attributes
  end

  def import_leads
    campaign = @list.campaign

    @voters_list.each_slice(1000).each do |voter_info_list|
      custom_fields = []
      leads = []
      updated_leads = {}

      found_leads = found_voters(voter_info_list) if custom_id_present?

      voter_info_list.each do |voter_info|
        phone_number = Voter.sanitize_phone(voter_info[@csv_phone_column_location])
        lead = nil

        if custom_id_present? 
          custom_id = voter_info[@csv_custom_id_column_location]
          lead_id = found_leads[custom_id]
          if lead_id.present?
            lead = {id: lead_id, voter_list_id: @list.id, enabled: true}
            updated_leads[custom_id] = lead
          end
        end

        lead ||= {
          :Phone         => phone_number,
          :voter_list_id => @list.id,
          :account_id    => @list.account_id,
          :campaign_id   => @list.campaign_id,
          :enabled       => true
        }

        @csv_headers.each_with_index do |csv_column_title, column_location|
          system_column = @csv_to_system_map.system_column_for csv_column_title
          value = voter_info[column_location]
          if !system_column.blank? && system_column != "Phone"
            if Voter.column_names.include? system_column
              lead[system_column] = value
            end
          end
        end

        if lead[:id] || Voter.phone_correct?(lead[:Phone])
          leads << lead
          @result[:successCount] +=1
        else
          @result[:failedCount] +=1
        end
      end

      created_ids = created_ids(@list.voters.reorder(:id)) do
        import_from_hashes(Voter, leads)
      end

      save_field_values(voter_info_list, created_ids, updated_leads)
    end
    @result
  end

  protected

  def found_voters(voter_info_list)
    custom_ids = voter_info_list.map do |voter_info|
      voter_info[@csv_custom_id_column_location]
    end
    query = Voter.where(CustomID: custom_ids, campaign_id: @list.campaign_id).select([:CustomID, :id]).to_sql
    Hash[*OctopusConnection.connection(:read_slave1).execute(query).to_a.flatten]
  end

  def created_ids(relation)
    last_id = relation.last.try(:id)
    yield
    last_id ? relation.where("id > #{last_id}").pluck(:id) : relation.pluck(:id)
  end


  def save_field_values(voter_info_list, created_ids, updated_leads)
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
        lead_id = created_ids.shift
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
