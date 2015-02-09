require 'impact_platform'

module CallFlow::DialQueue::Jobs
  class Monitor
    def self.perform
      active_campaigns = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1)")
      active_campaigns.each do |campaign|
        ImpactPlatform::Metrics.sample("dialer.dial_queue.numbers.available.count", campaign.dial_queue.available.size, "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}")
        ImpactPlatform::Metrics.sample("dialer.dial_queue.callers.available.count", campaign.caller_sessions.available.count, "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}")
        ImpactPlatform::Metrics.sample("dialer.dial_queue.callers.on_call.count", campaign.caller_sessions.on_call.count, "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}")
        ImpactPlatform::Metrics.sample("dialer.dial_queue.ringing.count", campaign.ringing_count, "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}")
        ImpactPlatform::Metrics.sample("dialer.dial_queue.presented.count", campaign.presented_count, "ac-#{campaign.account_id}.ca-#{campaign.id}.dm-#{campaign.type}")
      end
    end
  end
end
