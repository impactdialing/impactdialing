class AddTypeToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :type, :string)
  end

  def self.down
    remove_column(:caller_sessions, :type)
  end
end
