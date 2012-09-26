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

    create_custom_attributes(csv_headers, csv_to_system_map)
    voters_list.each_slice(1000).each do |voter_info_list|
      custom_fields = []
      leads = []
      voter_info_list.each do |voter_info|
        phone_number = Voter.sanitize_phone(voter_info[csv_phone_column_location])
        lead = nil

        if csv_custom_id_column_location.present?
          lead = Voter.find_by_CustomID_and_campaign_id(voter_info[csv_custom_id_column_location], @list.campaign_id)
          lead.update_attributes(voter_list: @list, enabled: true) if lead.present?
        end

        if lead.nil?
          lead = Voter.new(:Phone => phone_number, :voter_list => @list, :account_id => @list.account_id, :campaign_id => @list.campaign_id, enabled: true)
        end

        if lead.valid?
          leads << [lead, voter_info]
          result[:successCount] +=1
        else
          result[:failedCount] +=1
          next
        end
      end
      Voter.transaction do
        leads.each { |l, info| l.save }
      end
      leads.each do |lead, voter_info|
        csv_headers.each_with_index do |csv_column_title, column_location|
          system_column = csv_to_system_map.system_column_for csv_column_title
          if !system_column.blank? && system_column != "Phone"
            apply_attribute(lead, system_column, voter_info[column_location], custom_fields, campaign)
          end
        end
      end
      CustomVoterFieldValue.import custom_fields
    end
   result
 end


  def apply_attribute(voter, attribute, value, custom_fields, campaign)
    if voter.has_attribute? attribute
      voter.update_attributes(attribute => value)
    else
      custom_attribute = campaign.account.custom_voter_fields.find_by_name(attribute)
      custom_field_value = CustomVoterFieldValue.voter_fields(voter, custom_attribute).try(:first)
      if custom_field_value.present?
        custom_field_value.update_attributes(value: value)
      else
        custom_fields << CustomVoterFieldValue.new(voter: voter, custom_voter_field: custom_attribute, value: value)
      end
    end
  end


  def create_custom_attributes(csv_headers, csv_to_system_map)
    temp_voter = Voter.new
    csv_headers.each do |csv_column_title|
      system_column = csv_to_system_map.system_column_for csv_column_title
      if !system_column.blank? && !(temp_voter.has_attribute? system_column)
        custom_attribute = @list.account.custom_voter_fields.find_by_name(system_column)
        if custom_attribute.nil?
          CustomVoterField.create(:name => system_column, :account => @list.account)
        end
      end
    end
  end
end
