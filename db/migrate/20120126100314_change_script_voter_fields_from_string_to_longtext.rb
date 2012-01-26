class ChangeScriptVoterFieldsFromStringToLongtext < ActiveRecord::Migration
  def self.up
    change_column :scripts, :voter_fields, :longtext
  end

  def self.down
    change_column :scripts, :voter_fields, :string
  end
end
