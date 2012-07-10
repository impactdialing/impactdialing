class AddIndexesForCallDetails < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:campaign_id,:status,:last_call_attempt_time], :name => 'voters_campaign_status_time')
  end

  def self.down
  end
end
