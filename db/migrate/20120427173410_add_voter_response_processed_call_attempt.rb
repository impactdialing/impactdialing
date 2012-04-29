class AddVoterResponseProcessedCallAttempt < ActiveRecord::Migration
  def self.up
    add_column(:call_attempts, :voter_response_processed, :boolean, default: false)
    CallAttempt.connection.execute("update call_attempts set voter_response_processed = true where status = 'Call completed with success.'");
  end

  def self.down
    remove_column(:call_attempts, :voter_response_processed)
  end
end
