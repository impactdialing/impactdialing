class MigrateEnabledVoterListsToVoters < ActiveRecord::Migration
  def self.up
    Voter.connection.execute("update voters set enabled = (select enabled from voter_lists where voters.voter_list_id = voter_lists.id)");
  end

  def self.down
    Voter.connection.execute("update voters set enabled = false");
  end
end
