class AddSkippedTimeToVoter < ActiveRecord::Migration
  def self.up
     add_column :voters, :skipped_time, :datetime
  end

  def self.down
    remove_column :voters, :skipped_time
  end
end
