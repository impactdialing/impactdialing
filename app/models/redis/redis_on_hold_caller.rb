class RedisOnHoldCaller
      

  def self.redis_connection_pool
    $redis_on_hold_connection
  end

  def self.list(campaign_id)
    redis_connection_pool.with{|conn| Redis::List.new("campaign_id:#{campaign_id}:on_hold_caller", conn)}
    # Redis::List.new("campaign_id:#{campaign_id}:on_hold_caller", $redis_on_hold_connection)
  end
  
  def self.add(campaign_id, caller_session_id, callerdc="twilio")
    redis_connection_pool.with{|conn| conn.lpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id}
    # $redis_on_hold_connection.lpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id
  end
  
  def self.length(campaign_id, callerdc="twilio")
    redis_connection_pool.with{|conn| conn.llen "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"}
    # $redis_on_hold_connection.llen "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"
  end  
  
  def self.longest_waiting_caller(campaign_id, callerdc="twilio")
    redis_connection_pool.with{|conn| conn.rpop "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"}
    # $redis_on_hold_connection.rpop "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"
  end
  
  def self.remove_caller_session(campaign_id, caller_session_id, callerdc="twilio")
    redis_connection_pool.with{|conn| conn.lrem "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", 0, caller_session_id}
    # $redis_on_hold_connection.lrem "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", 0, caller_session_id
  end
  
  def self.add_to_bottom(campaign_id, caller_session_id, callerdc="twilio")
    redis_connection_pool.with{|conn| conn.rpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id}
    # $redis_on_hold_connection.rpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id
  end
end
