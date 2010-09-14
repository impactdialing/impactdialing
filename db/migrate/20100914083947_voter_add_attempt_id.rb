class VoterAddAttemptId < ActiveRecord::Migration
  def self.up
    add_index(:voters, :attempt_id)
  end

  def self.down
  end
end
