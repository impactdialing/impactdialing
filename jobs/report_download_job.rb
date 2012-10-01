require Rails.root.join("jobs/heroku_resque_auto_scale")
class ReportDownloadJob
  extend ::HerokuResqueAutoScale
  @queue = :report_download


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = NewReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy)
     report_job.perform
   end

   def self.after_perform_scale_down(*args)
     HerokuResqueAutoScale::Scaler.workers('report_download',1) if HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') == 1
   end

   def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('report_download') + HerokuResqueAutoScale::Scaler.pending_job_count('report_download_worker_job') - HerokuResqueAutoScale::Scaler.worker_count('report_download_worker_job')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('report_download') < 2
        HerokuResqueAutoScale::Scaler.workers('report_download', (HerokuResqueAutoScale::Scaler.working_job_count('report_download_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('report_download_worker_job')))
      end
    end

end