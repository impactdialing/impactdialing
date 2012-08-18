require Rails.root.join("lib/redis_connection")
class MonitorEvent
  
  def self.create_campaign_notification(campaign_id, event)
    MonitorSession.sessions(campaign_id).each do|monitor_session|
      $redis_monitor_connection.rpush('monitor_notifications', {channel: monitor_session, campaign: campaign_id, type: "update_campaign_info", event: event}.to_json)
    end
  end
  
  def self.create_caller_notification(campaign_id, caller_session_id, event, type="update_caller_info")    
    MonitorSession.sessions(campaign_id).each do|monitor_session|
      $redis_monitor_connection.rpush('monitor_notifications', {channel: monitor_session, campaign: campaign_id, caller_session: caller_session_id, event: event, type: type}.to_json)
    end
  end
  
  
  
  def self.call_ringing(campaign)        
    $redis_monitor_connection.pipelined do
      MonitorCampaign.increment_ringing_lines(campaign.id, 1)
      MonitorCampaign.decrement_available(campaign.id, 1)            
      MonitorCampaign.decrement_remaining(campaign.id, 1)            
    end
    create_campaign_notification(campaign.id, "ringing")
  end
      
  def self.incoming_call_request(campaign)
    MonitorCampaign.decrement_ringing_lines(campaign.id, 1)        
    create_campaign_notification(campaign.id, "incoming")
  end
    
    
  def self.voter_connected(campaign)
    $redis_monitor_connection.pipelined do
      MonitorCampaign.increment_on_call(campaign.id, 1)
      MonitorCampaign.decrement_on_hold(campaign.id, 1)
      MonitorCampaign.increment_live_lines(campaign.id, 1)                            
    end
    create_campaign_notification(campaign.id, 'voter_connected')
  end
  
  
  def self.caller_connected(campaign)
    $redis_monitor_connection.pipelined do
      MonitorCampaign.increment_callers_logged_in(campaign.id, 1)
      MonitorCampaign.increment_on_hold(campaign.id, 1)
    end
    create_campaign_notification(campaign.id, "caller_connected")
  end
  
    
  def self.voter_disconnected(campaign)
    $redis_monitor_connection.pipelined do
      MonitorCampaign.decrement_on_call(campaign.id, 1)
      MonitorCampaign.increment_wrapup(campaign.id, 1)
      MonitorCampaign.decrement_live_lines(campaign.id, 1)
    end
    create_campaign_notification(campaign.id, "voter_disconnected")
  end
    
  def self.voter_response_submitted(campaign)
    $redis_monitor_connection.pipelined do
      MonitorCampaign.decrement_wrapup(campaign.id, 1)
      MonitorCampaign.increment_on_hold(campaign.id, 1)
    end
    create_campaign_notification(campaign.id, "response_submitted")
  end
    
  def self.caller_disconnected(campaign)
    num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining = MonitorCampaign.campaign_overview_info(campaign)
    MonitorCampaign.new(campaign.id, num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining)        
    create_campaign_notification(campaign.id, "caller_disconnected")
  end    
  
end