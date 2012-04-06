class AlterRecycleRatesToFitNewValues < ActiveRecord::Migration
  def self.up
    Campaign.connection.execute("update campaigns set recycle_rate = 6 where recycle_rate = 7");
    Campaign.connection.execute("update campaigns set recycle_rate = 16 where recycle_rate in (14,15)");
    Campaign.connection.execute("update campaigns set recycle_rate = 12 where recycle_rate in (11,13)");
  end

  def self.down
  end
end
