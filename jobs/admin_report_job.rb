require 'reports'
class AdminReportJob
  @queue = :upload_download

  class << self
    def prepare_date(date)
      date.utc.strftime("%Y-%m-%d %H:%M:%S")
    end

    def perform(from, to)
      @from_date = Time.zone.parse(from).utc.beginning_of_day
      @to_date = Time.zone.parse(to).utc.end_of_day
      billable_minutes = Reports::BillableMinutes.new(@from_date, @to_date)

      report = Reports::Admin::EnterpriseByAccount.new(billable_minutes).build

      if ["aws", "heroku"].include?(ENV['RAILS_ENV'])
        UserMailer.new.deliver_admin_report(from, to, report)
      end
      report
    end
  end

end
