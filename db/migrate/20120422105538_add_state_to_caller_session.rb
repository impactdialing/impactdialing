class AddStateToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :state, :string)
  end

  def self.down
    remove_column(:caller_sessions, :state)
  end
end
