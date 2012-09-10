class AddUploadedFileNameVoterList < ActiveRecord::Migration
  def change
     add_column :voter_lists, :uploaded_file_name, :string
  end

end
