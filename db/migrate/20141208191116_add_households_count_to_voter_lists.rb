class AddHouseholdsCountToVoterLists < ActiveRecord::Migration
  def change
    add_column :voter_lists, :households_count, :integer
  end
end
