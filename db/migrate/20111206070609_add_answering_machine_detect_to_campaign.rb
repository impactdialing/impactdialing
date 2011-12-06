class AddAnsweringMachineDetectToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :answering_machine_detect, :boolean
  end

  def self.down
    remove_column :campaigns, :answering_machine_detect
  end
end
