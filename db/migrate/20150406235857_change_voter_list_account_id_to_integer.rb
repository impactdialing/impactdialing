class ChangeVoterListAccountIdToInteger < ActiveRecord::Migration
  def up
    change_column :voter_lists, :account_id, :integer
  end

  def down
    change_column :voter_lists, :account_id, :string
  end
end
