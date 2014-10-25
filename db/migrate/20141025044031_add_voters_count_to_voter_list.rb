class AddVotersCountToVoterList < ActiveRecord::Migration
  def change
    add_column :voter_lists, :voters_count, :integer, default: 0
  end
end
