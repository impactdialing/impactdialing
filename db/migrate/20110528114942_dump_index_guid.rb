class DumpIndexGuid < ActiveRecord::Migration
  def self.up
    add_index(:dumps, :guid)
  end

  def self.down
  end
end
