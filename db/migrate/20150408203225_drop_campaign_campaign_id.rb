class DropCampaignCampaignId < ActiveRecord::Migration
  def change
    remove_column :campaigns, :campaign_id, :integer
  end
end
