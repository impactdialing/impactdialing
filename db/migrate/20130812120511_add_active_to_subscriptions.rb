class AddActiveToSubscriptions < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :status, :string, default: "Trial"
  	add_column :subscriptions, :amount_paid, :float
  	add_column :subscriptions, :subscription_end_date, :timestamp
  end
end
