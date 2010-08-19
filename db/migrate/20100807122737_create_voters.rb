class CreateVoters < ActiveRecord::Migration
  def self.up
    create_table :voters do |t|
      all_headers=["Phone","CustomID","LastName","FirstName","MiddleName","Suffix","Email","result"]
      all_headers.each do |h|
        t.string h
      end
      t.integer :campaign_id
      t.integer :user_id
      t.boolean :active, :default=>true
      t.timestamps
    end
  end

  def self.down
    drop_table :voters
  end
end
