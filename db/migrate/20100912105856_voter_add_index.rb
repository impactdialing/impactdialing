class VoterAddIndex < ActiveRecord::Migration
  def self.up
    add_index(:voters, :voter_list_id)
    add_index(:voters, :Phone)
  end

  def self.down
  end
end
