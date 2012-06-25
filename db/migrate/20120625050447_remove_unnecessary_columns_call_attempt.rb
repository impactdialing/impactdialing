class RemoveUnnecessaryColumnsCallAttempt < ActiveRecord::Migration
  
  def self.up
    remove_column(:call_attempts, :caller_hold_time)
    remove_column(:call_attempts, :answertime)
    remove_column(:call_attempts, :result_json)
  end

  def self.down
  end
end
