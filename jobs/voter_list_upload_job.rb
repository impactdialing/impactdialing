require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListUploadJob 
  extend ::HerokuResqueAutoScale
  @queue = :voter_list_upload_worker_job

   def self.perform(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job = VoterListJob.new(separator, column_headers, csv_to_system_map, filename, voter_list_name, campaign_id, account_id, domain, email, callback_url, strategy="webui")
     job.perform
   end
   
   def after_perform_scale_down(*args)
     Scaler.workers(@queue.to_s,1) if Scaler.working_job_count(@queue.to_s) == 1
   end
   
   def after_enqueue_scale_up(*args)
      workers_to_scale = Scaler.working_job_count(@queue.to_s) + Scaler.pending_job_count(@queue.to_s) - Scaler.worker_count(@queue.to_s)
      if workers_to_scale > 0 && Scaler.working_job_count(@queue.to_s) <= 3
        Scaler.workers(@queue, Scaler.working_job_count(@queue.to_s) + Scaler.pending_job_count(@queue.to_s) + 1)
      end
    end
   
   
end