class AddFamily < ActiveRecord::Migration
  def self.up
    add_column :voters, :Age, :string
    add_column :voters, :Gender, :string
    add_column :voters, :num_family, :integer, :default=>1
    add_column :voters, :family_id_answered, :integer
    create_table "families", :force => true do |t|
      t.integer  "voter_id"
      t.string   "Phone"
      t.string   "CustomID"
      t.string   "LastName"
      t.string   "FirstName"
      t.string   "MiddleName"
      t.string   "Suffix"
      t.string   "Email"
      t.string   "result"
      t.integer  "campaign_id"
      t.integer  "user_id"
      t.boolean  "active",                 :default => true
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "status",                 :default => "not called"
      t.integer  "voter_list_id"
      t.integer  "caller_session_id"
      t.boolean  "call_back",              :default => false
      t.integer  "caller_id"
      t.string   "result_digit"
      t.string   "Age"
      t.string   "Gender"
      t.integer  "attempt_id"
      t.datetime "result_date"
      t.integer  "last_call_attempt_id"
      t.datetime "last_call_attempt_time"
    end
  end

  def self.down
    drop_table :family
    remove_column :voters, :Age
    remove_column :voters, :Gender
    remove_column :voters, :family_id_answered
  end
end