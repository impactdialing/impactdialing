class AddIndexCallAttemptsOnCampaignIdCreatedAtStatus < ActiveRecord::Migration
  def change
    add_index(:call_attempts, [:campaign_id, :created_at, :status], :name => 'index_call_attempts_on_campaign_id_created_at_status')
  end
end
