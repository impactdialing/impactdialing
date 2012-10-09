class VoterListBatchUpload

  def initialize(list)
    @list = list
  end


  def import_leads(csv_to_system_map, csv_filename, separator)
    result = {:successCount => 0, :failedCount => 0}
    csv = CSV.new(VoterList.read_from_s3(csv_filename).value, :col_sep => separator)
    csv_headers = csv.shift.compact
    voters_list = csv.readlines.shuffle

    csv_to_system_map.remap_system_column! "ID", :to => "CustomID"
    csv_phone_column_location = csv_headers.index(csv_to_system_map.csv_index_for "Phone")    
    csv_custom_id_column_location = csv_headers.index(csv_to_system_map.csv_index_for "CustomID")
    campaign = @list.campaign

    custom_attributes = create_custom_attributes(csv_headers, csv_to_system_map)

    voters_list.each_slice(1000).each do |voter_info_list|
      custom_fields = []
      leads = []
      updated_leads = {}
      voter_info_list.each do |voter_info|
        phone_number = Voter.sanitize_phone(voter_info[csv_phone_column_location])
        lead = nil

        if csv_custom_id_column_location.present?
          custom_id = voter_info[csv_custom_id_column_location]
          lead = Voter.find_by_CustomID_and_campaign_id(custom_id, @list.campaign_id)
          if lead.present?
            updated_leads[custom_id] = lead
            lead.voter_list = @list
            lead.enabled = true
          end
        end

        lead ||= {
          :Phone       => phone_number,
          :voter_list_id  => @list.id,
          :account_id  => @list.account_id,
          :campaign_id => @list.campaign_id,
          :enabled     => true
        }

        csv_headers.each_with_index do |csv_column_title, column_location|
          system_column = csv_to_system_map.system_column_for csv_column_title
          value = voter_info[column_location]
          if !system_column.blank? && system_column != "Phone"
            if Voter.column_names.include? system_column
              if lead.is_a?(Hash)
                lead[system_column] = value
              else
                lead.send("#{system_column}=", value)
              end
            end
          end
        end

        if Voter.phone_correct?(lead.is_a?(Hash) ? OpenStruct.new(lead) : lead)
          leads << lead
          result[:successCount] +=1
        else
          result[:failedCount] +=1
        end
      end

      Voter.transaction do
        leads.reject { |o| o.is_a?(Hash) }.each(&:save)
      end

      last_id = @list.voters.reorder(:id).last.try(:id)
      new_leads = leads.select { |o| o.is_a?(Hash) }
      if new_leads.any?
        column_names = new_leads.first.keys
        values = new_leads.map(&:values)
        Voter.import column_names, values
      end

      if last_id
        created_ids = @list.voters.reorder(:id).where("id > #{last_id}").pluck(:id)
      else
        created_ids = @list.voters.reorder(:id).pluck(:id)
      end

      custom_voter_values = []
      custom_field_values = CustomVoterFieldValue.where(voter_id: updated_leads.values.map(&:id), custom_voter_field_id: custom_attributes.values).all
      voter_info_list.each do |voter_info|
        if csv_custom_id_column_location.present? && updated_leads && updated_leads[voter_info[csv_custom_id_column_location]]
          lead_id = updated_leads[voter_info[csv_custom_id_column_location]].id
        else
          lead_id = created_ids.shift
        end
        csv_headers.each_with_index do |csv_column_title, column_location|
          system_column = csv_to_system_map.system_column_for csv_column_title
          value = voter_info[column_location]
          custom_attribute = custom_attributes[system_column]
          custom_field_value = custom_field_values.find { |v| v.voter_id == lead_id && v.custom_voter_field_id == custom_attribute }
          if custom_field_value.present?
            custom_field_value.value = value
          else
            custom_field_value = {
              voter_id: lead_id,
              custom_voter_field_id: custom_attribute,
              value: value
            }
          end
          custom_voter_values << custom_field_value
        end
      end
      CustomVoterFieldValue.transaction do
        custom_voter_values.reject { |o| o.is_a?(Hash) }.each(&:save)
      end
      new_values = custom_voter_values.select { |o| o.is_a?(Hash) }
      if new_values.any?
        column_names = new_values.first.keys
        values = new_values.map(&:values)
        CustomVoterFieldValue.import column_names, values
      end
    end
   result
 end

  def create_custom_attributes(csv_headers, csv_to_system_map)
    result = {}
    temp_voter = Voter.new
    csv_headers.each do |csv_column_title|
      system_column = csv_to_system_map.system_column_for csv_column_title
      if !system_column.blank? && !(temp_voter.has_attribute? system_column)
        custom_attribute = @list.account.custom_voter_fields.find_by_name(system_column)
        custom_attribute ||= CustomVoterField.create(:name => system_column, :account => @list.account)
        result[system_column] = custom_attribute.id
      end
    end
    result
  end

end
