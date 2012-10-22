require 'resque/errors'

require Rails.root.join("jobs/heroku_resque_auto_scale")
class ReportDownloadJob
  extend ::HerokuResqueAutoScale
  @queue = :report_download

  class << self

    def perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
      begin
        report_job = NewReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters, lead_dial, from, to, callback_url, strategy)
        report_job.perform
      rescue Resque::TermException
        puts "Restarting Downlod report job campaign_id: #{campaign_id}, user_id: #{user_id}, from: #{from}, to: #{to}, strategy: #{strategy}"
        Resque.enqueue(self, campaign_id, user_id, voter_fields, custom_fields, all_voters, lead_dial, from, to, callback_url, strategy)
      end
    end

    def after_perform_scale_down(*args)
      HerokuResqueAutoScale::Scaler.workers('report_download',1) if HerokuResqueAutoScale::Scaler.working_job_count('report_download') == 1
    end

    def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('report_download') +
        HerokuResqueAutoScale::Scaler.pending_job_count('report_download') -
        HerokuResqueAutoScale::Scaler.worker_count('report_download')

      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('report_download') < 2
        HerokuResqueAutoScale::Scaler.workers('report_download', (HerokuResqueAutoScale::Scaler.working_job_count('report_download') +
                                                                  HerokuResqueAutoScale::Scaler.pending_job_count('report_download')))
      end
    end

  end

end
