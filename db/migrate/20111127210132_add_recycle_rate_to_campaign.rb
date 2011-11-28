class AddRecycleRateToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :recycle_rate, :integer
  end

  def self.down
    remove_column :campaigns, :recycle_rate
  end
end
