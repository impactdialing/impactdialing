class RemoveLockVersionFromCallerSession < ActiveRecord::Migration
  def up
    remove_column :caller_sessions, :lock_version
  end

  def down
    add_column :caller_sessions, :lock_version
  end
end
