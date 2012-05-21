require 'resque/plugins/lock'
class ReportDownloadJob 
  extend Resque::Plugins::Director
  direct :min_workers => 0, :max_workers => 10, :max_time => 60, :max_queue => 2, :wait_time => 30
  @queue = :report_download


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = ReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
end