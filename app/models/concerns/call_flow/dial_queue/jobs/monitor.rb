require 'impact_platform/metrics'

module CallFlow::DialQueue::Jobs
  class Monitor
    def self.perform
      active_campaigns = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1)")
      active_campaigns.each do |campaign|
        source = "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}"
        prefix = "dialer.dial_queue"
        ImpactPlatform::Metrics.sample("#{prefix}.numbers.available.count", campaign.dial_queue.available.size, source)
        ImpactPlatform::Metrics.sample("#{prefix}.numbers.presented.count", campaign.dial_queue.available.all(:presented).size, source)
        ImpactPlatform::Metrics.sample("#{prefix}.numbers.recycled.count", campaign.dial_queue.recycle_bin.size, source)

        ImpactPlatform::Metrics.sample("#{prefix}.callers.available.count", campaign.caller_sessions.available.count, source)
        ImpactPlatform::Metrics.sample("#{prefix}.callers.on_call.count", campaign.caller_sessions.on_call.count, source)

        ImpactPlatform::Metrics.sample("#{prefix}.ringing.count", campaign.ringing_count, source)
        ImpactPlatform::Metrics.sample("#{prefix}.presented.count", campaign.presented_count, source)
      end
    end
  end
end
