class ChangeSubscriptionProviderStartPeriodAndProviderEndPeriodToInteger < ActiveRecord::Migration
  def up
    change_column :billing_subscriptions, :provider_start_period, :integer
    change_column :billing_subscriptions, :provider_end_period, :integer
  end

  def down
    change_column :billing_subscriptions, :provider_start_period, :timestamp
    change_column :billing_subscriptions, :provider_end_period, :timestamp
  end
end
