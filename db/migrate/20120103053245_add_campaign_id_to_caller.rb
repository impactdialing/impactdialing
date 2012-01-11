class AddCampaignIdToCaller < ActiveRecord::Migration
  def self.up
    add_column :callers, :campaign_id, :integer
  end

  def self.down
    remove_column :callers, :campaign_id
  end
end
