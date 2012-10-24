class AddIndexToBlockedNumbers < ActiveRecord::Migration
  def change
    add_index  :blocked_numbers, [:account_id, :campaign_id], name: :index_blocked_numbers_account_id_campaign_id
  end
end
