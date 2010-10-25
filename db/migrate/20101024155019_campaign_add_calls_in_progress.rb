class CampaignAddCallsInProgress < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :calls_in_progress, :boolean, :default=>false
  end

  def self.down
    remove_column :campaigns, :calls_in_progress
  end
end
