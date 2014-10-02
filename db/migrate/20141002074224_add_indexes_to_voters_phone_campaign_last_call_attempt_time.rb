class AddIndexesToVotersPhoneCampaignLastCallAttemptTime < ActiveRecord::Migration
  def change
    add_index :voters, [:phone, :campaign_id, :last_call_attempt_time], name: 'index_voters_on_phone_campaign_id_last_call_attempt_time'
  end
end
