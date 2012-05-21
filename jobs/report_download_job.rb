require 'resque/plugins/lock'
class ReportDownloadJob 
  extend Resque::Plugins::Lock
  @queue = :report


   def self.perform(campaign, user, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job = new ReportJob(campaign, user, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
end