class CreateBillingSubscriptions < ActiveRecord::Migration
  def change
    create_table :billing_subscriptions do |t|
      t.integer :account_id, null: false
      t.string :provider_subscription_id
      t.string :provider_status
      t.string :plan, null: false

      t.timestamps
    end
    add_index :billing_subscriptions, :account_id
    add_index :billing_subscriptions, :provider_subscription_id
  end
end
