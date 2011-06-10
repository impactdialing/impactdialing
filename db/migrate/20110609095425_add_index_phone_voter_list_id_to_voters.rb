class AddIndexPhoneVoterListIdToVoters < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:Phone, :voter_list_id], :unique => true)
  end

  def self.down
  end
end
