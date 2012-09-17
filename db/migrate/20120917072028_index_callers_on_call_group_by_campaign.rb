class IndexCallersOnCallGroupByCampaign < ActiveRecord::Migration
  def change
    remove_index(:voters, name: 'index_callers_on_call_group_by_campaign')
    add_index(:caller_sessions, [:campaign_id, :on_call], :name => 'index_callers_on_call_group_by_campaign')
  end
end
