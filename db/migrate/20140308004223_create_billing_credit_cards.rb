class CreateBillingCreditCards < ActiveRecord::Migration
  def change
    create_table :billing_credit_cards do |t|
      t.integer :account_id, null: false
      t.string :exp_month, null: false
      t.string :exp_year, null: false
      t.string :last4, null: false
      t.string :provider_id, null: false

      t.timestamps
    end
    add_index :billing_credit_cards, :account_id
  end
end
