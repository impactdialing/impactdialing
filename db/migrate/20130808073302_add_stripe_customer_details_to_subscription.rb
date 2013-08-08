class AddStripeCustomerDetailsToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :cc_last4, :string
  	add_column :subscriptions, :exp_month, :string
  	add_column :subscriptions, :exp_year, :string
  end
end
