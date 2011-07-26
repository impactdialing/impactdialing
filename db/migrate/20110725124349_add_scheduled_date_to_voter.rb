class AddScheduledDateToVoter < ActiveRecord::Migration
  def self.up
    add_column :voters, :scheduled_date, :datetime
  end

  def self.down
    remove_column :voters, :scheduled_date
  end
end
