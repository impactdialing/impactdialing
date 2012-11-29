class AddIndexToCallAttemptsForReport < ActiveRecord::Migration
  def change
    add_index(:call_attempts, [:campaign_id, :created_at, :id], :name => 'index_call_attempts_on_campaign_created_id')
  end
end
