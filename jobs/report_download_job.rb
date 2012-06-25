require Rails.root.join("jobs/heroku_resque_auto_scale")
class ReportDownloadJob 
  extend ::HerokuResqueAutoScale
  @queue = :worker_job


   def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     puts "dddddd"
     puts from
     puts to
     report_job = NewReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
     report_job.perform     
   end
   
   def on_failure_report(exception, *args)
     campaign = Campaign.find(args[0])
     user = User.find(args[1])
     strategy = args[7]     
     account_id = campaign.account_id
     callback_url = args[6]
     response_strategy = strategy == 'webui' ?  ReportWebUiStrategy.new("failure", user, campaign, account_id, exception) : ReportApiStrategy.new("failure", campaign.id, account_id, callback_url)
     response_strategy.response({})
   end 
end