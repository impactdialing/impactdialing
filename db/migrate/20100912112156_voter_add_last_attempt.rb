class VoterAddLastAttempt < ActiveRecord::Migration
  def self.up
    add_column :voters, :last_call_attempt_id, :integer
    add_column :voters, :last_call_attempt_time, :datetime
    ActiveRecord::Base.connection.execute("update voters set last_call_attempt_time = updated_at")
  end

  def self.down
    remove_column :voters, :last_call_attempt_time
    remove_column :voters, :last_call_attempt_id
  end
end
