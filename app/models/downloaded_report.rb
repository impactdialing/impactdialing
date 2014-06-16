class DownloadedReport < ActiveRecord::Base
  belongs_to :user
  belongs_to :campaign

  scope :with_user, where('user_id IS NOT NULL')
  scope :without_user, where('user_id IS NULL')
  scope :active_reports, lambda{|campaign_id, internal_admin|
    query = where(campaign_id: campaign_id).
    where(['created_at > ?', 24.hours.ago]).
    order('created_at DESC')

    unless internal_admin
      query = query.with_user
    end
    query
  }

  def self.accounts_active_report_count(campaign_ids, internal_admin=false)
    query = DownloadedReport.select("campaign_id").where("campaign_id in (?) AND (created_at > ?)", campaign_ids, 24.hours.ago)
    unless internal_admin
      query = query.with_user
    end
    query.group("campaign_id").count
  end
end
