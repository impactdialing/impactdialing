require Rails.root.join("jobs/heroku_resque_auto_scale")
class VoterListUploadJob 
  extend ::HerokuResqueAutoScale
  @queue = :list_upload

   def self.perform(voter_list_id, email, domain, callback_url, strategy="webui")
     voter_list = VoterList.find(voter_list_id)
     job = VoterListJob.new( voter_list.id , domain, email, callback_url, strategy="webui")
     job.perform
   end
   
   def self.after_perform_scale_down(*args)
     HerokuResqueAutoScale::Scaler.workers('list_upload',1) if HerokuResqueAutoScale::Scaler.working_job_count('list_upload') == 1
   end
   
   def self.after_enqueue_scale_up(*args)
      workers_to_scale = HerokuResqueAutoScale::Scaler.working_job_count('list_upload') + HerokuResqueAutoScale::Scaler.pending_job_count('list_upload') - HerokuResqueAutoScale::Scaler.worker_count('list_upload')
      if workers_to_scale > 0 && HerokuResqueAutoScale::Scaler.working_job_count('list_upload') < 2
        HerokuResqueAutoScale::Scaler.workers('list_upload', (HerokuResqueAutoScale::Scaler.working_job_count('list_upload') + HerokuResqueAutoScale::Scaler.pending_job_count('list_upload')))
      end
    end
   
      
end