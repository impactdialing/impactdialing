class CreateVoterResults < ActiveRecord::Migration
  def self.up
    create_table :voter_results do |t|
      t.integer :caller_id
      t.integer :voter_id
      t.integer :campaign_id
      t.string :status, :default=>"not called"
      t.string :result
      t.integer :duration
      t.datetime :start_time
      t.datetime :end_time
      t.string :guid
      t.timestamps
    end
  end

  def self.down
    drop_table :voter_results
  end
end
