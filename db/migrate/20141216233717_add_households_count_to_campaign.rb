class AddHouseholdsCountToCampaign < ActiveRecord::Migration
  def change
    add_column :campaigns, :households_count, :integer, default: 0
  end
end
