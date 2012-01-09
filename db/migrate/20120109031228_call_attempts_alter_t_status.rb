class CallAttemptsAlterTStatus < ActiveRecord::Migration
  def self.up
    change_column :call_attempts, :tStatus, :string
    change_column :caller_sessions, :tStatus, :string
  end

  def self.down
    change_column :call_attempts, :tStatus, :integer
    change_column :caller_sessions, :tStatus, :integer
  end
end
