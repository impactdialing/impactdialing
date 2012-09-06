require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListUploadJob 
  extend ::HerokuResqueAutoScale
  @queue = :voter_list_upload_worker_job

   def self.perform(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job = VoterListJob.new(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job.perform
   end
   
   def self.after_perform_scale_down(*args)
     HerokuResqueAutoScale::Scaler.workers('voter_list_upload_worker_job',1) if HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') == 1
   end
   
   def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('voter_list_upload_worker_job') - HerokuResqueAutoScale::Scaler.worker_count('voter_list_upload_worker_job')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') < 6
        HerokuResqueAutoScale::Scaler.workers('voter_list_upload_worker_job', (HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('voter_list_upload_worker_job')))
      end
    end
   
      
end