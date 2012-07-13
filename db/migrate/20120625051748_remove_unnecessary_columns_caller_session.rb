class RemoveUnnecessaryColumnsCallerSession < ActiveRecord::Migration
  def self.up
    remove_column(:caller_sessions, :num_calls)
    remove_column(:caller_sessions, :avg_wait)
    remove_column(:caller_sessions, :hold_time_start)    
  end

  def self.down
  end
end
