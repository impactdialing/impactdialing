require Rails.root.join("lib/redis_connection")
class MonitorEvent
  
  def self.create_campaign_notification(campaign_id, event)
    MonitorSession.sessions(campaign_id).each do|monitor_session|
      $redis_monitor_connection.rpush('monitor_notifications', {channel: monitor_session, campaign: campaign_id, type: "update_campaign_info", event: event}.to_json)
    end
  end
  
  def self.create_caller_notification(campaign_id, caller_session_id, event, type="update_caller_info")    
    MonitorSession.sessions(campaign_id).each do|monitor_session|
      $redis_monitor_connection.rpush('monitor_notifications', {channel: monitor_session, campaign: campaign_id, caller_session: caller_session_id.to_s, event: event, type: type}.to_json)
    end
  end
  
  
  
  def self.call_ringing(campaign)        
    create_campaign_notification(campaign.id, "ringing")
  end
      
  def self.incoming_call_request(campaign)
    create_campaign_notification(campaign.id, "incoming")
  end
    
    
  def self.voter_connected(campaign)
    create_campaign_notification(campaign.id, 'voter_connected')
  end
    
  def self.voter_disconnected(campaign)
    create_campaign_notification(campaign.id, "voter_disconnected")
  end
    
  def self.voter_response_submitted(campaign)
    create_campaign_notification(campaign.id, "response_submitted")
  end
  
  def self.caller_connected(campaign)
    create_campaign_notification(campaign.id, "caller_connected")
  end
  
    
  def self.caller_disconnected(campaign)
    create_campaign_notification(campaign.id, "caller_disconnected")
  end    
  
end