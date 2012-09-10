class AddDummyDataToVoterLists < ActiveRecord::Migration
  def change
    VoterList.all.each do |voter_list|
      voter_list.separator = ","
      voter_list.headers = "[]"
      voter_list.s3path = "dummy"
      voter_list.csv_to_system_map = "{\"Phone\": \"Phone\"}"
      voter_list.uploaded_file_name = "dummy"
    end
  end
end
