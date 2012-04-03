class AccountAddSubscriptionInfo < ActiveRecord::Migration
  def self.up
    add_column :accounts, :subscription_name, :string
    add_column :accounts, :subscription_count, :integer
    add_column :accounts, :subscription_active, :boolean, :default=>false
    add_column :accounts, :recurly_subscription_uuid, :string
  end

  def self.down
    remove_column :accounts, :recurly_subscription_uuid
    remove_column :accounts, :subscription_count
    remove_column :accounts, :subscription_active
    remove_column :accounts, :subscription_name
  end
end