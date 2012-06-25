class DropCampaignsVoterLists < ActiveRecord::Migration
  def self.up
    drop_table :campaigns_voter_lists
  end

  def self.down
  end
end
