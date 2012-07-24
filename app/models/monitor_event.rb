require Rails.root.join("lib/redis_connection")
class MonitorEvent
  
  def self.create_notifications(campaign_id)
    redis = RedisConnection.monitor_connection
    MonitorSession.sessions(campaign_id).each do|monitor_session|
      redis.rpush('monitor_notifications', {channel: monitor_session, campaign: campaign_id}.to_json)
    end
  end
  
  
  def self.call_ringing(campaign)
    redis = RedisConnection.monitor_connection
    MonitorCampaign.increment_ringing_lines(campaign.id, 1)            
    create_notifications(campaign.id)
  end
      
  def self.incoming_call_request(campaign)
    redis = RedisConnection.monitor_connection
    puts "abcd"
    MonitorCampaign.decrement_ringing_lines(campaign.id, 1)        
    puts "defg"
    create_notifications(campaign.id)
  end
    
    
  def self.voter_connected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.increment_on_call(campaign.id, 1)
      MonitorCampaign.decrement_on_hold(campaign.id, 1)
      MonitorCampaign.increment_live_lines(campaign.id, 1)                            
    end
    create_notifications(campaign.id)
  end
  
  def self.caller_connected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.increment_callers_logged_in(campaign.id, 1)
      MonitorCampaign.increment_on_hold(campaign.id, 1)
    end
    create_notifications(campaign.id)
  end
  
    
  def self.voter_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.decrement_on_call(campaign.id, 1)
      MonitorCampaign.increment_wrapup(campaign.id, 1)
      MonitorCampaign.decrement_live_lines(campaign.id, 1)
    end
    create_notifications(campaign.id)
  end
    
  def self.voter_response_submitted(campaign)
    redis = RedisConnection.monitor_connection
    redis.pipelined do
      MonitorCampaign.decrement_wrapup(campaign.id, 1)
      MonitorCampaign.increment_on_hold(campaign.id, 1)
    end
    create_notifications(campaign.id)
  end
    
  def self.caller_disconnected(campaign)
    redis = RedisConnection.monitor_connection
    MonitorCampaign.decrement_callers_logged_in(campaign.id, 1)
    create_notifications(campaign.id)
  end    
  
end