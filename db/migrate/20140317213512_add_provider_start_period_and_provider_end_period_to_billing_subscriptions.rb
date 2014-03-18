class AddProviderStartPeriodAndProviderEndPeriodToBillingSubscriptions < ActiveRecord::Migration
  def change
    add_column :billing_subscriptions, :provider_start_period, :timestamp
    add_column :billing_subscriptions, :provider_end_period, :timestamp
  end
end
