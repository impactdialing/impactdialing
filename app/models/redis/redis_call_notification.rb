class RedisCallNotification
  
  def self.connected(identity)
    call_attempt = CallAttempt.find(identity)
    redis_call_attempt = RedisCallAttempt.read(identity)
    campaign = call_attempt.campaign
    MonitorEvent.incoming_call_request(campaign)      
    MonitorEvent.voter_connected(campaign) 
    MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], redis_call_attempt["status"])      
  end
  
  def self.end_answered_call(identity)
    call_attempt = CallAttempt.find(identity)
    redis_call_attempt = RedisCallAttempt.read(identity)
    campaign = call_attempt.campaign            
    MonitorEvent.voter_disconnected(campaign)
    MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], redis_call_attempt["status"])  
  end
  
  
  def self.wrapup(identity)
    call_attempt = CallAttempt.find(identity)
    campaign = call_attempt.campaign                  
    redis_call_attempt = RedisCallAttempt.read(identity)
    MonitorEvent.voter_response_submitted(campaign)
    MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], "On hold")
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "wrapup"}.to_json)
  end
  
  
  def self.abandoned(identity)
    call_attempt = CallAttempt.find(identity)
    campaign = call_attempt.campaign          
    MonitorEvent.incoming_call_request(campaign)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "wrapup"}.to_json)
  end
  
  
  def self.answered_by_machine(identity)
    call_attempt = CallAttempt.find(identity)
    campaign = call_attempt.campaign
    MonitorEvent.incoming_call_request(campaign)
  end
  
  def self.end_answered_by_machine(identity)
    call_attempt = CallAttempt.find(identity)
    campaign = call_attempt.campaign                            
    MonitorEvent.incoming_call_request(campaign)              
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "wrapup"}.to_json)
  end
  
  def self.end_unanswered_call(identity)
    call_attempt = CallAttempt.find(identity)
    campaign = call_attempt.campaign                              
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "wrapup"}.to_json)
  end
  
  def self.caller_connected(identity)
    caller_session = CallerSession.find(identity)
    campaign = caller_session.campaign
    MonitorEvent.caller_connected(campaign)
    MonitorEvent.create_caller_notification(campaign.id, caller_session.id, "caller_connected", "add_caller")    
  end
  
  def self.caller_disconnected(identity)
    caller_session = CallerSession.find(identity)
    campaign = caller_session.campaign
    MonitorEvent.caller_disconnected(campaign)
    MonitorEvent.create_caller_notification(campaign.id, caller_session.id, "caller_disconnected", "remove_caller")
  end
  
  
  
  
end