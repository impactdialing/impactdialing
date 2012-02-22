class AddCampaignIdAndWrapupTimeIndexCallAttempts < ActiveRecord::Migration
  def self.up
    add_index(:call_attempts, [:campaign_id,:wrapup_time])
  end

  def self.down
    remove_index(:call_attempts, [:campaign_id,:wrapup_time])
  end
end
