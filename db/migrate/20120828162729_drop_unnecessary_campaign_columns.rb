class DropUnnecessaryCampaignColumns < ActiveRecord::Migration
  def self.up
    remove_column :campaigns, :group_id
    remove_column :campaigns, :ratio_override
    remove_column :campaigns, :use_answering
    remove_column :campaigns, :callin_number
    remove_column :campaigns, :answer_detection_timeout
    remove_column :campaigns, :amd_turn_off
  end

  def self.down
  end
end
