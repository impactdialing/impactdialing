class AddCompositeIndexToSpeedQueries < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:campaign_id,:active, :status, :call_back])
    add_index(:answers, [:voter_id,:question_id])
    add_index(:call_attempts, [:caller_id,:wrapup_time])
    add_index(:call_attempts, [:campaign_id,:call_end])
  end

  def self.down
    remove_index(:voters, [:campaign_id,:active, :status, :call_back])
    remove_index(:answers, [:voter_id,:question_id])
    remove_index(:call_attempts, [:caller_id,:wrapup_time])
    remove_index(:call_attempts, [:campaign_id,:call_end])
  end
end
