class CampaignAddRecycleRateDefault < ActiveRecord::Migration
  def self.up
    change_column_default(:campaigns, :recycle_rate, 1)
  end

  def self.down
    change_column_default(:campaigns, :recycle_rate, nil)
  end
end
