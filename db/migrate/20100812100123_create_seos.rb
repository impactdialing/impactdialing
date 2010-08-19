class CreateSeos < ActiveRecord::Migration
  def self.up
    create_table "seos", :force => true do |t|
      t.string   "action"
      t.string   "controller"
      t.string   "crmkey"
      t.string   "title"
      t.string   "keywords"
      t.string   "description"
      t.text     "content",     :limit => 16777215
      t.boolean  "active"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "version"
    end
  end

  def self.down
    drop_table :seos
  end
end
