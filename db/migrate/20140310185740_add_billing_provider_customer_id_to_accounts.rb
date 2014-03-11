class AddBillingProviderCustomerIdToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :billing_provider_customer_id, :string
    add_column :accounts, :billing_provider, :string
  end
end
