module CallFlow::Jobs
  class ProcessRecycleBin
    @queue = :upload_download
    extend ImpactPlatform::Heroku::UploadDownloadHooks

    def self.perform(campaign_id)
      campaign   = Campaign.find(campaign_id)
      dial_queue = CallFlow::DialQueue.new(campaign)
      dial_queue.recycle!
    end
  end
end