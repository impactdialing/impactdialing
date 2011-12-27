class AddIndexToCustomVoterFields < ActiveRecord::Migration
  def self.up
    add_index(:custom_voter_field_values, :voter_id)
  end

  def self.down
    remove_index(:custom_voter_field_values, :voter_id)
  end
end
