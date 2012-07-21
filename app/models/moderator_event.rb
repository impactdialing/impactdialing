require Rails.root.join("lib/redis_connection")
class ModeratorEvent
  
  def self.create_job(campaign_id, event)
    Sidekiq::Client.push('queue' => 'monitor_worker', 'class' => ModeratorJob, 'args' => [campaign_id, event, Time.now])
  end
  
    
  def incoming_call(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do      
      ModeratorCampaign.decrement_ringing_lines(campaign.id, 1)        
    end
  end
    
    
  def voter_connected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      ModeratorCampaign.increment_on_call(campaign.id, 1)
      ModeratorCampaign.decrement_on_hold(campaign.id, 1)
      ModeratorCampaign.increment_live_lines(campaign.id, 1)                            
    end
  end
    
    
    
  def voter_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      ModeratorCampaign.decrement_on_call(campaign.id, 1)
      ModeratorCampaign.increment_wrapup(campaign.id, 1)
      ModeratorCampaign.decrement_live_lines(campaign.id, 1)
    end
  end
    
  def voter_response_submitted(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      ModeratorCampaign.decrement_wrapup(campaign.id, 1)
      ModeratorCampaign.increment_on_hold(campaign.id, 1)
    end
  end
    
  def caller_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    ModeratorCampaign.decrement_callers_logged_in(campaign.id, 1)
  end    
  
end