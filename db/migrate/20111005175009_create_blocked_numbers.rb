class CreateBlockedNumbers < ActiveRecord::Migration
  def self.up
    create_table :blocked_numbers do |t|
      t.string :number
      t.integer :user_id
      t.timestamps
    end
  end

  def self.down
    drop_table :blocked_numbers
  end
end
