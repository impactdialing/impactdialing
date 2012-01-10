class AddCampaignIdToAnswer < ActiveRecord::Migration
  def self.up
    add_column :answers, :campaign_id, :integer
  end

  def self.down
    remove_column :answers, :campaign_id
  end
end
