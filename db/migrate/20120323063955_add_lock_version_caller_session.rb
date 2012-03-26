class AddLockVersionCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :lock_version, :integer, default: 0)
  end

  def self.down
    remove_column(:caller_sessions, :lock_version)
  end
end
