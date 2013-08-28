class CreateTableSubscriptions < ActiveRecord::Migration
  def up
    create_table :subscriptions do |t|
      t.string :type, null: false, default: "Trial"
      t.integer :number_of_callers, default: 0
      t.integer :minutes_utlized, default: 0
      t.integer :total_allowed_minutes, default: 0
      t.integer :account_id
      t.datetime :subscription_start_date
      t.timestamps
    end
  end

  def down
    drop_table :subscriptions
  end
end
