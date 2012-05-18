class AddLockVersionToVoters < ActiveRecord::Migration
  def self.up
    add_column :voters, :lock_version, :integer, :default=>0
  end

  def self.down
    remove_column :voters, :lock_version
  end
end
