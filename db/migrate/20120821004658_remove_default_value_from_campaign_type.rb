class RemoveDefaultValueFromCampaignType < ActiveRecord::Migration
  def self.up
    change_column :campaigns, :type, :string, :default => nil
  end

  def self.down
    change_column :campaigns, :type, :string, :default => 'preview'
  end
end
