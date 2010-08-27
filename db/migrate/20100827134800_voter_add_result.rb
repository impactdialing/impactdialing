class VoterAddResult < ActiveRecord::Migration
  def self.up
    add_column :voters, :caller_id, :integer
    add_column :voters, :result_digit, :string
    add_column :voters, :attempt_id, :integer
    
    VoterResult.all.each do |result|
      begin
        voter = Voter.find(result.voter_id)
        voter.caller_id=result.caller_id
        voter.result_digit=result.status
        voter.save
      rescue
      end
    end
    drop_table :voter_results
  end

  def self.down
    create_table "voter_results", :force => true do |t|
      t.integer  "caller_id"
      t.integer  "voter_id"
      t.integer  "campaign_id"
      t.string   "status",      :default => "not called"
      t.string   "result"
      t.integer  "duration"
      t.datetime "start_time"
      t.datetime "end_time"
      t.string   "guid"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    
    remove_column :voters, :attempt_id
    remove_column :voters, :result_digit
    remove_column :voters, :caller_id
  end
end
