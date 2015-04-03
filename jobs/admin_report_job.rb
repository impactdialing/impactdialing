require 'reports'
require 'librato_resque'

##
# Build & email admin reports.
# For all or enterprise accounts.
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 error
#
class AdminReportJob
  @queue = :reports
  extend LibratoResque

  def self.perform(from, to, report_type, include_undebited)
    begin
      date_range       = Report::SelectiveDateRange.new([from], [to])
      billable_minutes = Reports::BillableMinutes.new(date_range.from, date_range.to)

      if report_type == 'All'
        report = Reports::Admin::AllByAccount.new(billable_minutes, include_undebited).build
      else
        report = Reports::Admin::EnterpriseByAccount.new(billable_minutes).build
      end

      if ["aws", "heroku"].include?(ENV['RAILS_ENV'])
        UserMailer.new.deliver_admin_report(from, to, report)
      else
        Rails.logger.info report
        p report
      end
      report
    rescue Resque::TermException => e
      Resque.enqueue(self, from, to, report_type, include_undebited)
    end
  end
end
