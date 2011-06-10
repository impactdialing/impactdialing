module VoterListsHelper
  def matching_system_header_for(csv_header)
    normalized_csv_header = csv_header.upcase.gsub(' ', '')
    VoterList::VOTER_DATA_COLUMNS.find do |system_header|
      system_header.upcase.gsub(' ', '') == normalized_csv_header
    end
  end
end
