require 'redis/hash_key'
class RedisAvailableCaller
  include Redis::Objects
  
  def self.available_callers_set(campaign_id)
    redis = RedisConnection.call_flow_connection
    Redis::SortedSet.new("available_caller:#{campaign_id}", redis)    
  end
  
  def self.add_caller(campaign_id, caller_session_id)
    available_callers_set(campaign_id).zadd(Time.now.to_i, caller_session_id)
  end
  
  def self.remove_caller(campaign_id, caller_session_id)
    available_callers_set(campaign_id).zrem(caller_session_id)
  end
  
  def self.longest_waiting_caller(campaign_id)
  end
  
  def self.assign_longest_available_caller(campaign_id)    
  end
  
end