require 'redis/hash_key'
class RedisAvailableCaller
  include Redis::Objects
  
  def self.add_caller(campaign_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    sorted_set = Redis::SortedSet.new("available_caller:#{campaign_id}", redis)
    sorted_set.zadd(Time.now.to_i, caller_session_id)
  end
  
  def self.remove_caller(campaign_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    sorted_set = Redis::SortedSet.new("available_caller:#{campaign_id}", redis)
    sorted_set.zrem(caller_session_id)
  end
  
  def self.longest_waiting_caller(campaign_id)
  end
  
  def self.assign_longest_available_caller(campaign_id)    
  end
  
end