class AccountAddLockVersion < ActiveRecord::Migration
  def self.up
    add_column :accounts, :lock_version, :integer, :default=>0
    add_column :accounts, :status, :string
  end

  def self.down
    remove_column :accounts, :lock_version
    remove_column :accounts, :status
  end
end