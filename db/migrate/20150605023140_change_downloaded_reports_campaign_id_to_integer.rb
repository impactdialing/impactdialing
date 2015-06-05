class ChangeDownloadedReportsCampaignIdToInteger < ActiveRecord::Migration
  def up
    change_column :downloaded_reports, :campaign_id, :integer
  end

  def down
    change_column :downloaded_reports, :campaign_id, :string
  end
end
