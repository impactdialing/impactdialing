class AddPurposeToVoterList < ActiveRecord::Migration
  def change
    add_column :voter_lists, :purpose, :string, default: 'import'
  end
end
