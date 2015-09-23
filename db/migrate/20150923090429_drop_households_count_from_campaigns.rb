class DropHouseholdsCountFromCampaigns < ActiveRecord::Migration
  def up
    remove_column :campaigns, :households_count
  end

  def down
    add_column :campaigns, :households_count, :integer
  end
end
