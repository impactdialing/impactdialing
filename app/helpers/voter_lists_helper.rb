module VoterListsHelper
  def matching_system_header_for(csv_header)
    normalized_csv_header = csv_header.upcase.gsub(' ', '')
    match = VoterList::VOTER_DATA_COLUMNS.find do |system_header|
      system_header.upcase.gsub(' ', '') == normalized_csv_header
    end
    match ||= ('DWID' if normalized_csv_header.include? 'ID')
    match
  end

  def system_column_headers
    @system_column_headers ||= [["Not available", nil]].concat (VoterList::VOTER_DATA_COLUMNS.zip(VoterList::VOTER_DATA_COLUMNS))
  end
end
