class AddScheduledDateToCallAttempt < ActiveRecord::Migration
  def self.up
    add_column :call_attempts, :scheduled_date, :datetime
  end

  def self.down
    remove_column :call_attempts, :scheduled_date
  end
end
