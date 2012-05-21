require 'resque/plugins/lock'
class ReportDownloadJob 
  direct :min_workers => 0, :max_workers => 10, :max_time => 60, :max_queue => 2, :wait_time => 30
  @queue = :report_download


   def self.perform(campaign, user, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = new ReportJob(campaign, user, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
end