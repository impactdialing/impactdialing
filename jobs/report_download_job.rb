class ReportDownloadJob 
  extend HerokuResqueAutoScale
  @queue = :worker_job


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = ReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
end