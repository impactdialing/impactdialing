class AddWrapupTimeToCallAttempt < ActiveRecord::Migration
  def self.up
     add_column :call_attempts, :wrapup_time, :datetime
   end

   def self.down
     remove_column :call_attempts, :wrapup_time
   end
end
