class AddEndCallerSession < ActiveRecord::Migration
  def self.up
    add_column :caller_sessions, :ended, :boolean, :default => false
  end

  def self.down
    remove_column :caller_sessions, :ended
  end
end
