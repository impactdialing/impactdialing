class AddIndexPhoneVoterListIdToVoters < ActiveRecord::Migration
  def self.up
#    add_index(:voters, [:Phone, :voter_list_id], :unique => true) #this is more desirable, but test phone numbers preclude it from working
    add_index(:voters, [:Phone, :voter_list_id])
  end

  def self.down
  end
end
