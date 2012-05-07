class AddVoterResponseProcessedCallAttempt < ActiveRecord::Migration
  def self.up
    add_column(:call_attempts, :voter_response_processed, :boolean, default: false)
  end

  def self.down
    remove_column(:call_attempts, :voter_response_processed)
  end
end
