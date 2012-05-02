class AddDebitToCallAttemptAndCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:call_attempts, :debited, :boolean, default: false)
    CallAttempt.connection.execute("update call_attempts set debited = true");
    add_column(:caller_sessions, :debited, :boolean, default: false)
    CallerSession.connection.execute("update caller_sessions set debited = true");
  end

  def self.down
    remove_columns(:call_attempts, :debited)
    remove_columns(:caller_sessions, :debited)
  end
end
