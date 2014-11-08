require 'reports'
require 'impact_platform/heroku'
require 'librato_resque'

##
# Email account usage reports to customers.
# See +Client::AccountUsagesController#create+.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class ReportAccountUsageJob
  extend ImpactPlatform::Heroku::UploadDownloadHooks
  extend TimeZoneHelper
  extend LibratoResque
  
  @queue = :upload_download

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
