class AddPeriodToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :start_time, :time
    add_column :campaigns, :end_time, :time
  end

  def self.down
    remove_column :campaigns, :start_time
    remove_column :campaigns, :end_time
  end
end
