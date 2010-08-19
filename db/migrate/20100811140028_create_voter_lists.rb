class CreateVoterLists < ActiveRecord::Migration
  def self.up
    create_table :voter_lists do |t|
      t.string :name
      t.string :user_id
      t.boolean :active, :default=>true
      t.timestamps
    end
  end

  def self.down
    drop_table :voter_lists
  end
end
