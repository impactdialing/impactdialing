require 'resque/errors'
require 'impact_platform/heroku'

class ReportDownloadJob
  @queue = :upload_download
  extend UploadDownloadHooks

  def self.perform(campaign_id, user_id, voter_fields, custom_fields, all_voters,lead_dial, from, to, callback_url, strategy="webui")
    begin
      report_job = NewReportJob.new(campaign_id, user_id, voter_fields, custom_fields, all_voters, lead_dial, from, to, callback_url, strategy)
      report_job.perform
    rescue Resque::TermException
      puts "Restarting Downlod report job campaign_id: #{campaign_id}, user_id: #{user_id}, from: #{from}, to: #{to}, strategy: #{strategy}"
      Resque.enqueue(self, campaign_id, user_id, voter_fields, custom_fields, all_voters, lead_dial, from, to, callback_url, strategy)
    end
  end
end
