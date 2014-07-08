require 'reports'
require 'impact_platform/heroku'

class ReportAccountUsageJob
  @queue = :upload_download
  extend UploadDownloadHooks
  extend TimeZoneHelper

  def self.perform(report_type, user_id, from_date, to_date, internal_admin=false)
    method = "mail_#{report_type}_usage"
    self.send(method, user_id, from_date, to_date, internal_admin)
  end

  def self.mail_campaigns_usage(user_id, from_date, to_date, internal_admin)
    user   = User.find user_id
    report = AccountUsageMailer.new(user, internal_admin)
    report.by_campaigns(from_date, to_date)
  end

  def self.mail_callers_usage(user_id, from_date, to_date, internal_admin)
    user   = User.find user_id
    report = AccountUsageMailer.new(user, internal_admin)
    report.by_callers(from_date, to_date)
  end
end
