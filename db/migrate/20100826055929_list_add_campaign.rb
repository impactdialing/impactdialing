class ListAddCampaign < ActiveRecord::Migration
  def self.up
    add_column :voter_lists, :campaign_id, :integer
    add_column :scripts, :incompletes, :string
    add_column :voters, :call_back, :boolean, :default=>false
  end

  def self.down
    remove_column :voters, :call_back
    remove_column :scripts, :incompletes
    remove_column :voter_lists, :column_name
  end
end
