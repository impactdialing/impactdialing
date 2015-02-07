module Archival::Jobs
  class Campaign
    @queue = :background_worker
    
    def self.add_to_queue(campaign_id)
      Resque.enqueue(self, campaign_id)
    end

    def self.perform(campaign_id)
      campaign = Campaign.find campaign_id
      campaign.callers.update_all(campaign_id: nil)
    end
  end
end
