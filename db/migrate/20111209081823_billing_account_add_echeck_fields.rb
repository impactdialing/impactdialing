class BillingAccountAddEcheckFields < ActiveRecord::Migration
  def self.up
    add_column :billing_accounts, :checking_account_number, :string
    add_column :billing_accounts, :bank_routing_number, :string
    add_column :billing_accounts, :drivers_license_number, :string
    add_column :billing_accounts, :drivers_license_state, :string
    add_column :billing_accounts, :checking_account_type, :string
  end

  def self.down
    remove_column :billing_accounts, :checking_account_number
    remove_column :billing_accounts, :bank_routing_number
    remove_column :billing_accounts, :drivers_license_number
    remove_column :billing_accounts, :drivers_license_state
    remove_column :billing_accounts, :checking_account_type
  end
end