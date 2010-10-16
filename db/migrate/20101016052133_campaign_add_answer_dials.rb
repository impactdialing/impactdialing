class CampaignAddAnswerDials < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :answer_detection_timeout, :integer, :default=>20
  end

  def self.down
    remove_column :campaigns, :answer_detection_timeout
  end
end
