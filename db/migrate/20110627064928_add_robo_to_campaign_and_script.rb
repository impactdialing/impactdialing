class AddRoboToCampaignAndScript < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :robo, :boolean, :default => false
    add_column :scripts, :robo, :boolean, :default => false
  end

  def self.down
    remove_column :scripts, :robo
    remove_column :campaigns, :robo
  end
end
