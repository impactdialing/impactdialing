class CreateAccount < ActiveRecord::Migration
  def self.up
    create_table "accounts", :force => true do |t|
      t.integer  "user_id"
      t.string   "cc"
      t.boolean  "active"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "cardtype"
      t.integer  "expires_month"
      t.integer  "expires_year"
      t.string   "last4"
      t.string   "zip"
      t.string   "address1"
    end
  end

  def self.down
    drop_table :accounts
  end
end