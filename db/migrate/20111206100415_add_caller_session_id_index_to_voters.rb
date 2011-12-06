class AddCallerSessionIdIndexToVoters < ActiveRecord::Migration
  def self.up
    add_index(:voters, :caller_session_id)
  end

  def self.down
    remove_index(:voters, :caller_session_id)
  end
end
