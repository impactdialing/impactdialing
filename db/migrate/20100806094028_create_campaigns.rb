class CreateCampaigns < ActiveRecord::Migration
  def self.up
    create_table :campaigns do |t|
      t.string :campaign_id
      t.string :group_id
      t.string :name
      t.string :keypad_1
      t.string :keypad_2
      t.string :keypad_3
      t.string :keypad_4
      t.string :keypad_5
      t.string :keypad_6
      t.string :keypad_7
      t.string :keypad_8
      t.string :keypad_9
      t.string :keypad_0
      t.integer :user_id
      t.integer :script_id
      t.boolean :active, :default=>true
      t.timestamps
    end
  end

  def self.down
    drop_table :campaigns
  end
end
