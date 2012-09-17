require 'redis/hash_key'

class RedisAvailableCaller  
  include Redis::Objects
  
  def self.available_callers_set(campaign_id)
    Redis::SortedSet.new("available_caller:#{campaign_id}", $redis_call_flow_connection)    
  end
  
  def self.add_caller(campaign_id, caller_session_id)
    available_callers_set(campaign_id).add(caller_session_id, Time.now.to_i)
  end
  
  def self.remove_caller(campaign_id, caller_session_id)
    available_callers_set(campaign_id).delete(caller_session_id)
  end
  
  def self.count(campaign_id)
    available_callers_set(campaign_id).length
  end
  
  def self.zero?(campaign_id)
    available_callers_set(campaign_id).length == 0
  end
  
  
  def self.caller?(campaign_id, caller_session_id)
    available_callers_set(campaign_id).member?(caller_session_id)
  end
  
  def self.longest_waiting_caller(campaign_id)
    callers = available_callers_set(campaign_id).range(-1,-1)
    callers.empty? ? nil : callers.first
  end
    
end