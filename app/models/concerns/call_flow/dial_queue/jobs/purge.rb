require 'librato_resque'

module CallFlow::DialQueue::Jobs
  class Purge
    @queue = :general
    extend LibratoResque

    def self.add_to_queue(campaign_id)
      Resque.enqueue(self, campaign_id)
    end

    def self.perform(campaign_id)
      campaign = Campaign.find(campaign_id)
      campaign.dial_queue.purge
    end
  end
end
