module CallFlow::Jobs
  class CacheAvailableVoters
    include Resque::Plugins::UniqueJob
    @queue = :dialer_worker

    def self.perform(campaign_id)
      metrics    = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore.split('/').last)
      campaign   = Campaign.find campaign_id
      dial_queue = CallFlow::DialQueue.new(campaign)

      if dial_queue.below_threshold?
        dial_queue.top_off
      end
      metrics.completed
    end
  end
end
