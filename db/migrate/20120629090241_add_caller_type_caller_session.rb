class AddCallerTypeCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :caller_type, :string)
  end

  def self.down
    remove_column(:caller_sessions, :caller_type)
  end
end
