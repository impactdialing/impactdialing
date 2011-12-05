class AddAmdTurnOffToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :amd_turn_off, :boolean
  end

  def self.down
    remove_column :campaigns, :amd_turn_off
  end
end
