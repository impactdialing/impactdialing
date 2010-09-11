class CallAttemptsAddIndex < ActiveRecord::Migration
  def self.up
    add_index(:call_attempts, :voter_id)
    add_index(:call_attempts, :campaign_id)
  end

  def self.down
  end
end
