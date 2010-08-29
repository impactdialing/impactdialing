class VoterListEnabled < ActiveRecord::Migration
  def self.up
    add_column :voter_lists, :enabled, :boolean, :default=>1
  end

  def self.down
    remove_column :voter_lists, :enabled
  end
end
