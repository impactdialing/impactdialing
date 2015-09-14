module VoterListsHelper
  def matching_system_header_for(csv_header)
    normalized_csv_header = csv_header.upcase.gsub(' ', '')
    match = VoterList::VOTER_DATA_COLUMNS.keys.find do |system_header|
      system_header.upcase.gsub(' ', '') == normalized_csv_header
    end
    match ||= ('DWID' if normalized_csv_header.include? 'ID')
    match || csv_header
  end

  def selected_system_or_custom_header_for(csv_header, account, use_custom_ids=true)
    normalized_header = csv_header.underscore.strip
    select_options    = system_column_headers(csv_header, account, use_custom_ids)
    selected = select_options.find do |select_option|
      select_option.include?(normalized_header) or
      select_option.include?(csv_header.strip)
    end
    selected.try(:last)
  end

  def system_column_headers(csv_header, account, use_custom_ids=true)
    #custom_options = CallFlow::Web::ContactFields::Options.new(account).all
    custom_options = account.custom_voter_fields.map(&:name)
    #custom_options.uniq!

    basic_header = [["(Discard this column)", nil]]
    basic_header.concat(VoterList::VOTER_DATA_COLUMNS.values.zip(VoterList::VOTER_DATA_COLUMNS.keys))
    basic_header.concat(custom_options.map{|field| [field, field]})
    unless use_custom_ids
      basic_header.reject!{|tuples| tuples.include?('custom_id')}
    end
    basic_header << ["Add custom field...", "custom"]
  end
end
