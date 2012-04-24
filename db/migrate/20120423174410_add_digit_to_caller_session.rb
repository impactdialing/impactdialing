class AddDigitToCallerSession < ActiveRecord::Migration
  def self.up
    add_column(:caller_sessions, :digit, :string)
  end

  def self.down
    remove_column(:caller_sessions, :digit)
  end
end
