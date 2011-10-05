class AddCampaignToBlockedNumber < ActiveRecord::Migration
  def self.up
    add_column :blocked_numbers, :campaign_id, :integer
  end

  def self.down
    remove_column :blocked_numbers, :campaign_id
  end
end
