class CampaignUseScript < ActiveRecord::Migration
  def self.up
    change_column_default(:campaigns, :use_web_ui, 1)
  end

  def self.down
    change_column_default(:campaigns, :use_web_ui, 0)
  end
end
