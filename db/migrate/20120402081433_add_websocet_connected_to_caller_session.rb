class AddWebsocetConnectedToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :websocket_connected, :boolean)
  end

  def self.down
    remove_column(:caller_sessions, :websocket_connected)
  end
end
