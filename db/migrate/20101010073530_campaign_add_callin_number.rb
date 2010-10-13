class CampaignAddCallinNumber < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :callin_number, :string, :default=>"4157020991"
  end

  def self.down
    remove_column :campaigns, :callin_number
  end
end
