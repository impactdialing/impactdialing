class AddIndexCallersOnCallGroupCampaign < ActiveRecord::Migration
  def change
    add_index(:voters, [:campaign_id, :enabled, :priority, :status], :name => 'index_callers_on_call_group_by_campaign')
  end
end
