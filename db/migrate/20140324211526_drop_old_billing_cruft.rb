class DropOldBillingCruft < ActiveRecord::Migration
  def up
    remove_column :accounts, :card_verified
    remove_column :accounts, :recurly_account_code
    remove_column :accounts, :subscription_name
    remove_column :accounts, :subscription_count
    remove_column :accounts, :subscription_active
    remove_column :accounts, :recurly_subscription_uuid
    remove_column :accounts, :autorecharge_enabled
    remove_column :accounts, :autorecharge_trigger
    remove_column :accounts, :autorecharge_amount
    remove_column :accounts, :credit_card_declined
    
    remove_column :call_attempts, :payment_id
    remove_column :caller_sessions, :payment_id

    drop_table :billing_accounts
    drop_table :payments
    drop_table :subscriptions
  end

  def down
    raise "Non-reversible migration."
  end
end
