class CreateScripts < ActiveRecord::Migration
  def self.up
    create_table :scripts do |t|
      t.string :name
      t.text :script
      t.boolean :active, :default=>true
      t.integer :user_id
      t.timestamps
      (1..99).each{|i| 
        t.string :"keypad_#{i}"
      }
    end
  end

  def self.down
    drop_table :scripts
  end
end
