class RedisCallNotification
  
  def self.connected(identity)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "call_connected"}.to_json)
  end
  
  def self.end_answered_call(identity)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "end_answered_call"}.to_json)
  end
  
  
  def self.wrapup(identity)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "wrapup"}.to_json)
  end
  
  
  def self.abandoned(identity)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {identity: identity, event: "call_abandoned"}.to_json)
  end
  
  
  def self.answered_by_machine(identity)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {identity: identity, event: "answered_by_machine"}.to_json)    
  end
  
  def self.end_answered_by_machine(identity)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {identity: identity, event: "end_answered_by_machine"}.to_json)    
  end
  
  def self.end_unanswered_call(identity)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {identity: self.id, event: "end_unanswered_call"}.to_json)
  end
  
  def self.caller_connected(identity)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "caller_connected"}.to_json)
  end
  
  def self.caller_disconnected(caller_session_id)
    RedisConnection.common_connection.rpush('connected_call_notification', {identity: identity, event: "caller_disconnected"}.to_json)
  end
  
  
  
  
end