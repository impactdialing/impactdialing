require Rails.root.join("lib/redis_connection")
class MonitorEvent
  
  def self.create_job(campaign_id, event)
    Sidekiq::Client.push('queue' => 'monitor_worker', 'class' => ModeratorJob, 'args' => [campaign_id, event, Time.now])
  end
  
    
  def incoming_call(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do      
      MonitorCampaign.decrement_ringing_lines(campaign.id, 1)        
    end
  end
    
    
  def voter_connected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.increment_on_call(campaign.id, 1)
      MonitorCampaign.decrement_on_hold(campaign.id, 1)
      MonitorCampaign.increment_live_lines(campaign.id, 1)                            
    end
  end
    
    
    
  def voter_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.decrement_on_call(campaign.id, 1)
      MonitorCampaign.increment_wrapup(campaign.id, 1)
      MonitorCampaign.decrement_live_lines(campaign.id, 1)
    end
  end
    
  def voter_response_submitted(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.decrement_wrapup(campaign.id, 1)
      MonitorCampaign.increment_on_hold(campaign.id, 1)
    end
  end
    
  def caller_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    MonitorCampaign.decrement_callers_logged_in(campaign.id, 1)
  end    
  
end