class AddTableTempVoterList < ActiveRecord::Migration
  def self.up
    create_table :temp_voter_lists do |t|
      t.string :name
      t.timestamps
    end
    
  end

  def self.down
    drop_table :temp_voter_lists
  end
end
