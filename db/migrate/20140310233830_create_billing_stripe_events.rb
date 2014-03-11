class CreateBillingStripeEvents < ActiveRecord::Migration
  def change
    create_table :billing_stripe_events do |t|
      t.string :provider_id, null: false
      t.date :provider_created_at
      t.string :name
      t.string :request
      t.integer :pending_webhooks
      t.text :data
      t.timestamp :processed
      t.boolean :livemode

      t.timestamps
    end
    add_index :billing_stripe_events, :provider_id
  end
end
