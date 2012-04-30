class AddIndexesToCallAttempt < ActiveRecord::Migration
  def self.up
    add_index(:call_attempts, :call_id)
    add_index(:call_attempts, [:voter_response_processed,:status])
    add_index(:call_attempts, [:debited,:call_end])
  end

  def self.down
    remove_index(:call_attempts, :call_id)
    remove_index(:call_attempts, [:voter_response_processed,:status])
    remove_index(:call_attempts, [:debited,:call_end])    
  end
end
