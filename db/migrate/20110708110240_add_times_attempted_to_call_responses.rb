class AddTimesAttemptedToCallResponses < ActiveRecord::Migration
  def self.up
    add_column :call_responses, :robo_recording_id, :integer
    add_column :call_responses, :times_attempted, :integer, :default => 0
  end

  def self.down
    remove_column :call_responses, :robo_recording_id
    remove_column :call_responses, :times_attempted
  end
end
