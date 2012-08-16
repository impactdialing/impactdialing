require Rails.root.join("lib/redis_connection")
require 'redis/hash_key'

class RedisAvailableCaller  
  include Redis::Objects
  
  def self.available_callers_set(campaign_id, redis_connection)
    Redis::SortedSet.new("available_caller:#{campaign_id}", redis_connection)    
  end
  
  def self.add_caller(campaign_id, caller_session_id, redis_connection)
    available_callers_set(campaign_id, redis_connection).add(caller_session_id, Time.now.to_i)
  end
  
  def self.remove_caller(campaign_id, caller_session_id, redis_connection)
    available_callers_set(campaign_id, redis_connection).delete(caller_session_id)
  end
  
  def self.caller?(campaign_id, caller_session_id, redis_connection)
    available_callers_set(campaign_id, redis_connection).member?(caller_session_id)
  end
  
  def self.longest_waiting_caller(campaign_id, redis_connection)
    available_callers_set(campaign_id, redis_connection).range(-1,-1)
  end
  
  def self.assign_longest_available_caller(campaign_id)    
  end
  
end