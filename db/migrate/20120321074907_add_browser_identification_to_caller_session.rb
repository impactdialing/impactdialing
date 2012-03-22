class AddBrowserIdentificationToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :browser_identification, :string)
  end

  def self.down
    remove_column(:caller_sessions, :browser_identification)
  end
end
