class Useraddpaid < ActiveRecord::Migration
  def self.up
    add_column :users, :paid, :boolean, :default=>false
  end

  def self.down
    remove_column :users, :paid
  end
end
