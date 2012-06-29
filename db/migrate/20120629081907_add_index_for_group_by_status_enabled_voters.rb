class AddIndexForGroupByStatusEnabledVoters < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:enabled, :campaign_id,:last_call_attempt_time,:status], :name => 'voters_enabled_campaign_time_status')    
  end

  def self.down
  end
end
