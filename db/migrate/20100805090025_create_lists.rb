class CreateLists < ActiveRecord::Migration
  def self.up
    create_table :lists do |t|
      t.string :name
      t.integer :group_id
      t.integer :user_id
      t.timestamps
    end
  end

  def self.down
    drop_table :lists
  end
end
