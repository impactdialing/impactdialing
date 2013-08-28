class AddAutorechargeFieldsToSubscription < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :autorecharge_enabled, :boolean, default: false
  	add_column :subscriptions, :autorecharge_amount, :float
  	add_column :subscriptions, :autorecharge_trigger, :float
  	
  	
  end
end
