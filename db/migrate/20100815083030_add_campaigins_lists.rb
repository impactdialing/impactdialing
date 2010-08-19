class AddCampaiginsLists < ActiveRecord::Migration
  def self.up
    create_table :campaigns_voter_lists, :id => false do |t|
      t.references :campaign, :voter_list
    end
    create_table :callers_campaigns, :id => false do |t|
      t.references :caller, :campaign
    end
  end

  def self.down
    drop_table :campaigns_voter_lists
    drop_table :callers_campaigns
  end
end
