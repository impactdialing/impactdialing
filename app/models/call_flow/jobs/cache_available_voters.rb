class CacheAvailableVoters
  include Resque::Plugins::UniqueJob
  @queue = :dialer_worker

  def self.perform(campaign_id)
    metrics    = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)
    campaign   = Campaign.find campaign_id
    dial_queue = CallFlow::DialQueue.new(campaign)

    if dial_queue.below_threshold?(:available)
      dial_queue.prepend(:available)
    end
    metrics.completed
  end
end
