class AccountAddRecurlyAccountCode < ActiveRecord::Migration
  def self.up
    add_column :accounts, :recurly_account_code, :string
    remove_column :accounts, :chargify_customer_id
  end

  def self.down
    remove_column :accounts, :recurly_account_code
    add_column :accounts, :chargify_customer_id, :integer
  end
end