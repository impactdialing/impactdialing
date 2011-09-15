class RenameAccountToBillingAccount < ActiveRecord::Migration
  def self.up
    rename_table :accounts, :billing_accounts
  end

  def self.down
    rename_table :billing_accounts, :accounts
  end
end
