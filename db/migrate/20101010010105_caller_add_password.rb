class CallerAddPassword < ActiveRecord::Migration
  def self.up
    add_column :callers, :password, :string
    add_column :caller_sessions, :session_key, :string
  end

  def self.down
    remove_column :caller_sessions, :session_key
    remove_column :callers, :password
  end
end
