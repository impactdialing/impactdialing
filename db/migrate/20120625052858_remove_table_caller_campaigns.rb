class RemoveTableCallerCampaigns < ActiveRecord::Migration
  def self.up
    drop_table :callers_campaigns
  end

  def self.down
  end
end
