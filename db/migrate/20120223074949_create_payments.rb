class CreatePayments < ActiveRecord::Migration
  def self.up
    create_table :payments do |t|
      t.float :amount_paid
      t.float :amount_remaining
      t.integer :recurly_transaction_uuid
      t.integer :account_id
      t.string :notes
      t.timestamps
    end
  end

  def self.down
    drop_table :payments
  end
end
