module VoterListsHelper
  def matching_system_header_for(csv_header)
    normalized_csv_header = csv_header.upcase.gsub(' ', '')
    match = VoterList::VOTER_DATA_COLUMNS.keys.find do |system_header|
      system_header.upcase.gsub(' ', '') == normalized_csv_header
    end
    match ||= ('DWID' if normalized_csv_header.include? 'ID')
    match
  end

  def system_column_headers(csv_header, account)
    basic_header = [["Not available", nil]]
    basic_header << ["#{csv_header} (Custom)", csv_header] unless VoterList::VOTER_DATA_COLUMNS.values.include?(csv_header)
    basic_header.concat(VoterList::VOTER_DATA_COLUMNS.values.zip(VoterList::VOTER_DATA_COLUMNS.keys))
    basic_header.concat(account.custom_voter_fields.map(&:name).map{|field| ["#{field} (Custom)", field]})
  end
end
