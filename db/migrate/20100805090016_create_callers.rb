class CreateCallers < ActiveRecord::Migration
  def self.up
    create_table :callers do |t|
      t.string :name
      t.string :email
      t.string :pin
      t.integer :user_id
      t.boolean :multi_user, :default=>true
      t.timestamps
    end
  end

  def self.down
    drop_table :callers
  end
end
