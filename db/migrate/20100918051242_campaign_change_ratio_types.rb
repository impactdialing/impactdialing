class CampaignChangeRatioTypes < ActiveRecord::Migration
  def self.up
    change_column :campaigns, :ratio_2, :float
    change_column :campaigns, :ratio_3, :float
    change_column :campaigns, :ratio_4, :float
    change_column :campaigns, :ratio_override, :float
  end

  def self.down
    change_column :campaigns, :ratio_2, :integer
    change_column :campaigns, :ratio_3, :integer
    change_column :campaigns, :ratio_4, :integer
    change_column :campaigns, :ratio_override, :integer
  end
end
