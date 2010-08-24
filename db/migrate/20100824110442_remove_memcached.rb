class RemoveMemcached < ActiveRecord::Migration
  def self.up
    add_column :caller_sessions, :on_call, :boolean, :default=>false
  end

  def self.down
    remove_column :caller_sessions, :on_call
  end
end
