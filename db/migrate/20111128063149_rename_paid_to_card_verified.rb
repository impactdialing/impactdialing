class RenamePaidToCardVerified < ActiveRecord::Migration
  def self.up
    rename_column :accounts, :paid, :card_verified
    add_column :accounts, :activated, :boolean, :default => false
    execute 'update accounts set activated = card_verified'
  end

  def self.down
    remove_column :accounts, :activated
    rename_column :accounts, :card_verified, :paid
  end
end
