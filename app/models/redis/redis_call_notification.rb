class RedisCallNotification
  
  def self.connected(call_attempt_id)
    RedisConnection.common_connection.rpush('connected_call_notification', {call_attempt: call_attempt_id, event: "call_connected"}.to_json)
  end
  
  def self.abandoned(call_attempt_id)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: call_attempt_id, event: "call_abandoned"}.to_json)
  end
  
  def self.end_answered_call(call_attempt_id)
    RedisConnection.common_connection.rpush('connected_call_notification', {call_attempt: call_attempt_id, event: "end_answered_call"}.to_json)
  end
  
  def self.answered_by_machine(call_attempt_id)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: call_attempt_id, event: "answered_by_machine"}.to_json)    
  end
  
  def self.end_answered_by_machine(call_attempt_id)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: call_attempt_id, event: "end_answered_by_machine"}.to_json)    
  end
  
  def self.end_unanswered_call(call_attempt_id)
    RedisConnection.common_connection.rpush('notconnected_call_notification', {call_attempt: self.id, event: "end_unanswered_call"}.to_json)
  end
  
end