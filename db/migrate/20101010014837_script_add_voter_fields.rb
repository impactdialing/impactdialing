class ScriptAddVoterFields < ActiveRecord::Migration
  def self.up
    add_column :scripts, :voter_fields, :string
  end

  def self.down
    remove_column :scripts, :voter_fields
  end
end
