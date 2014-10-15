require 'resque-loner'

module CallFlow::Jobs
  class ActiveCallerMonitor
    include Resque::Plugins::UniqueJob
    @queue = :alert_worker

    def self.perform    
      active_campaigns    = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1 )")
      active_caller_count = CallerSession.on_call.count

      ImpactPlatform::Metrics.count('dialer.active.caller_sessions.total', active_caller_count)
      ImpactPlatform::Metrics.count('dialer.active.campaigns.total', active_campaigns.count)
      active_campaigns.each do |campaign|
        ImpactPlatform::Metrics.count("dialer.active.caller_sessions", campaign.caller_sessions.on_call.count, "ac-#{campaign.account_id}.ca-#{campaign.id}")
      end
    end
  end
end
