require 'resque/plugins/lock'
class ReportDownloadJob 
  extend Resque::Plugins::Director
  direct :min_workers => 1, :max_workers => 10, :max_time => 60, :max_queue => 1, :wait_time => 30
  @queue = :worker_job


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = ReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
end