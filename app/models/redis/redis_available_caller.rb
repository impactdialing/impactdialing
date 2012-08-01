class RedisAvailableCaller
  
  def self.add_caller(campaign_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.zadd "available_caller:#{campaign_id}", Time.now.to_i, caller_session_id    
  end
  
  def self.remove_caller(campaign_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.zrem "available_caller:#{campaign_id}", caller_session_id    
  end
  
  def self.longest_waiting_caller(campaign_id)
  end
  
end