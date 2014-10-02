class AddIndexesToBlockedNumbers < ActiveRecord::Migration
  def change
    add_index(:blocked_numbers, [:account_id, :campaign_id, :number], name: 'index_blocked_numbers_on_account_campaign_number')
  end
end
