class CreateTableTransfer < ActiveRecord::Migration
  def self.up
    create_table :transfers do |t|
      t.string :label
      t.string :phone_number
      t.string :type
      t.integer :script_id
      t.timestamps
    end    
  end

  def self.down
    drop_table :transfers
  end
end
