class AddAcceptableAbandonRateToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :acceptable_abandon_rate, :float
  end

  def self.down
    remove_column :campaigns, :acceptable_abandon_rate
  end
end
