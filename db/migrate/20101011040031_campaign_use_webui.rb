class CampaignUseWebui < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :use_web_ui, :boolean, :default=>false
  end

  def self.down
    remove_column :campaigns, :use_web_ui
  end
end
