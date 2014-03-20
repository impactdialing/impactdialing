class DropStatusFromBillingSubscription < ActiveRecord::Migration
  def up
    remove_column :billing_subscriptions, :status
  end

  def down
    add_column :billing_subscription, :status, :string
  end
end
