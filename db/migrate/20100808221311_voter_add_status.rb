class VoterAddStatus < ActiveRecord::Migration
  def self.up
    add_column :voters, :status, :string, :default=>"not called"
    add_column :voters, :voter_list_id, :integer
  end

  def self.down
    remove_column :voters, :list_id
    remove_column :voters, :status
  end
end
