class CreateTransferAttempts < ActiveRecord::Migration
    def self.up
      create_table :transfer_attempts do |t|
        t.integer :transfer_id
        t.integer :caller_session_id
        t.integer :call_attempt_id
        t.integer :script_id
        t.integer :campaign_id
        t.datetime :call_start
        t.datetime :call_end
        t.string :status
        t.datetime :connecttime
        t.string :sid
        t.string :session_key        
        t.timestamps
      end
    end    

  def self.down
    drop_table :transfers
  end
end
