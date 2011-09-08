class EditCallerSessions < ActiveRecord::Migration
  def self.up
    rename_column :caller_sessions, :voter_in_progress, :voter_in_progress_id
  end

  def self.down
    rename_column :caller_sessions, :voter_in_progress_id, :voter_in_progress
  end
end
