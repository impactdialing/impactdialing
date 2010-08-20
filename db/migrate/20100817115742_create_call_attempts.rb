class CreateCallAttempts < ActiveRecord::Migration
  def self.up
    create_table :call_attempts do |t|
      t.integer :voter_id
      t.string :sid
      t.string :status
      t.integer :campaign_id
      t.datetime :call_start
      t.datetime :call_end
      t.integer :caller_id
      t.datetime :connecttime
      t.integer :caller_session_id
      t.timestamps
    end
  end

  def self.down
    drop_table :call_attempts
  end
end
