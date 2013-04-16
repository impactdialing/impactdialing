class AddReassignCampaignToCallerSession < ActiveRecord::Migration
  def change
    add_column :caller_sessions, :reassign_campaign, :string, default: "no"
  end
end
