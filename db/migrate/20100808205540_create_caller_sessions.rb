class CreateCallerSessions < ActiveRecord::Migration
  def self.up
    create_table :caller_sessions do |t|
      t.integer :caller_id
      t.integer :campaign_id
      t.datetime :endtime
      t.datetime :starttime
      t.integer :num_calls
      t.integer :avg_wait
      t.string :sid
      t.boolean :available_for_call, :default=>false
      t.integer :voter_in_progress
      t.datetime :hold_time_start
      t.timestamps
    end
  end

  def self.down
    drop_table :caller_sessions
  end
end
