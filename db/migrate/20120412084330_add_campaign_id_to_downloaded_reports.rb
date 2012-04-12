class AddCampaignIdToDownloadedReports < ActiveRecord::Migration
  def self.up
    add_column(:downloaded_reports, :campaign_id, :string)
  end

  def self.down
    remove_column(:downloaded_reports, :campaign_id)
  end
end
