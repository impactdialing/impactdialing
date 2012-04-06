class ChangeNullRecycleRateTo1 < ActiveRecord::Migration
  def self.up
    Campaign.connection.execute("update campaigns set recycle_rate = 1 where recycle_rate is null");
  end

  def self.down
  end
end
