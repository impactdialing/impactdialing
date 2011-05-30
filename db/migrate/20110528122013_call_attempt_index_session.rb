class CallAttemptIndexSession < ActiveRecord::Migration
  def self.up
    add_index(:call_attempts, :caller_session_id)
  end

  def self.down
  end
end
