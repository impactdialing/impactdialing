class AddActiveToSubscriptions < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :status, :string, default: "Trial"
  end
end
