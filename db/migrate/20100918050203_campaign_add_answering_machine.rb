class CampaignAddAnsweringMachine < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :use_answering, :boolean, :default=>true
  end

  def self.down
    remove_column :campaigns, :use_answering
  end
end
