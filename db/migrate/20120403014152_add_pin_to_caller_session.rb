class AddPinToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :pin, :string)
  end

  def self.down
    remove_column(:caller_sessions, :pin)
  end
end
