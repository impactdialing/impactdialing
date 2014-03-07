class CreateQuotas < ActiveRecord::Migration
  def change
    create_table :quotas do |t|
      t.integer :account_id, null: false
      t.integer :minutes_used, null: false, default: 0
      t.integer :minutes_pending, null: false, default: 0
      t.integer :minutes_allowed, null: false, default: 0
      t.integer :callers_allowed, null: false, default: 0
      t.boolean :disable_calling, null: false, default: false

      t.timestamps
    end
    add_index :quotas, :account_id
  end
end
