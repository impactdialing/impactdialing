class AddTimeZoneToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :time_zone, :string
  end

  def self.down
    remove_column :campaigns, :time_zone
  end
end
