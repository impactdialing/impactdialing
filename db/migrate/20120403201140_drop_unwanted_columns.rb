class DropUnwantedColumns < ActiveRecord::Migration
  def self.up
    remove_column(:caller_sessions, :browser_identification)
    remove_column(:caller_sessions, :websocket_connected)
    remove_column(:caller_sessions, :pin)
  end

  def self.down
    add_column(:caller_sessions, :browser_identification, :string)
    add_column(:caller_sessions, :websocket_connected, :boolean)
    add_column(:caller_sessions, :pin, :string)
  end
end
