module CallFlow::Jobs
  class ProcessPresentedVoters
    @queue = :upload_download
    extend ImpactPlatform::Heroku::UploadDownloadHooks

    def self.perform(campaign_id)
      campaign   = Campaign.find(campaign_id)
      dial_queue = CallFlow::DialQueue.new(campaign)
      stale      = dial_queue.available.presented_and_stale
      stale.each do |scored_phone|
        score     = scored_phone.last
        phone     = scored_phone.first
        household = campaign.households.find_by_phone(phone)
        household.update_attributes({
          presented_at: score
        })
        dial_queue.dialed(household)
      end

      dial_queue.recycle!
    end
  end
end
