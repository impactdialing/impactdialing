class RedisOnHoldCaller  
  
  def self.list(campaign_id)
    Redis::List.new("campaign_id:#{campaign_id}:on_hold_caller", $redis_on_hold_connection)
  end
  
  def self.add(campaign_id, caller_session_id, callerdc)
    $redis_on_hold_connection.lpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id
  end
  
  def self.length(campaign_id, callerdc)
    $redis_on_hold_connection.llen "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"
  end  
  
  def self.longest_waiting_caller(campaign_id, callerdc)
    $redis_on_hold_connection.rpop "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller"
  end
  
  def self.remove_caller_session(campaign_id, caller_session_id, callerdc)
    $redis_on_hold_connection.lrem "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", 0, caller_session_id
  end
  
  def self.add_to_bottom(campaign_id, caller_session_id, callerdc)
    $redis_on_hold_connection.rpush "campaign_id:#{campaign_id}:#{callerdc}:on_hold_caller", caller_session_id
  end
  
end