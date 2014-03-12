class CreateBillingSubscriptions < ActiveRecord::Migration
  def change
    create_table :billing_subscriptions do |t|
      t.integer :account_id, null: false
      t.string :provider_id
      t.string :provider_status
      t.string :status
      t.string :plan, null: false
      t.text :settings

      t.timestamps
    end
    add_index :billing_subscriptions, :account_id
    add_index :billing_subscriptions, :provider_id
  end
end
