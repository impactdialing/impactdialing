class AddCampaignIdToCallResponse < ActiveRecord::Migration
  def self.up
    add_column :call_responses, :campaign_id, :integer
  end

  def self.down
    remove_column :call_responses, :campaign_id
  end
end
