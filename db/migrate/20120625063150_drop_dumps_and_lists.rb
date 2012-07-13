class DropDumpsAndLists < ActiveRecord::Migration
  def self.up
    drop_table :dumps
    drop_table :lists
  end

  def self.down
  end
end
