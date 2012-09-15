require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListUploadJob 
  extend ::HerokuResqueAutoScale
  @queue = :voter_list_upload_worker_job

   def self.perform(voter_list_id, email, domain, callback_url, strategy="webui")
     voter_list = VoterList.find(voter_list_id)
     job = VoterListJob.new( voter_list.id , domain, email, callback_url, strategy="webui")
     job.perform
   end
   
   def self.after_perform_scale_down(*args)
     HerokuResqueAutoScale::Scaler.workers('voter_list_upload_worker_job',1) if HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') == 1
   end
   
   def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('voter_list_upload_worker_job') - HerokuResqueAutoScale::Scaler.worker_count('voter_list_upload_worker_job')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') < 2
        HerokuResqueAutoScale::Scaler.workers('voter_list_upload_worker_job', (HerokuResqueAutoScale::Scaler.working_job_count('voter_list_upload_worker_job') + HerokuResqueAutoScale::Scaler.pending_job_count('voter_list_upload_worker_job')))
      end
    end
   
      
end