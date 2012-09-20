class AddColumnsToVoterList < ActiveRecord::Migration

  def change
    add_column :voter_lists, :separator, :string
    add_column :voter_lists, :headers, :text
    add_column :voter_lists, :csv_to_system_map, :text
    add_column :voter_lists, :s3path, :text    
  end
end
