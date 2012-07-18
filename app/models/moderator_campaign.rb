class ModeratorCampaign
  
  def initialize(campaign_id, num_callers_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, 
    num_available, num_remaining)
    redis = Redis.current
    redis.hdel  "moderator:#{campaign_id}", "callers_logged_in"
    redis.hdel  "moderator:#{campaign_id}", "on_call"
    redis.hdel  "moderator:#{campaign_id}", "on_hold"
    redis.hdel  "moderator:#{campaign_id}", "ringing_lines"
    redis.hdel  "moderator:#{campaign_id}", "wrapup"
    redis.hdel  "moderator:#{campaign_id}", "live_lines"
    redis.hdel  "moderator:#{campaign_id}", "avaialble"
    redis.hdel  "moderator:#{campaign_id}", "remaining"    
    
    redis.hincrby "moderator:#{campaign_id}", "callers_logged_in", num_callers_logged_in
    redis.hincrby "moderator:#{campaign_id}", "on_call", num_on_call
    redis.hincrby "moderator:#{campaign_id}", "on_hold", num_on_hold
    redis.hincrby "moderator:#{campaign_id}", "ringing_lines", num_ringing_lines    
    redis.hincrby "moderator:#{campaign_id}", "wrapup", num_wrapup    
    redis.hincrby "moderator:#{campaign_id}", "live_lines", num_live_lines        
    redis.hincrby "moderator:#{campaign_id}", "available", num_available        
    redis.hincrby "moderator:#{campaign_id}", "available", num_remaining            
  end
  
  ['callers_logged_in', 'on_call', 'on_hold', 'wrapup', 'live_lines', 'ringing_lines' ].each do |value|
    define_singleton_method("increment_#{value}") do |campaign_id, num|
      redis = Redis.current
      redis.hincrby "moderator:#{campaign_id}", value, num
    end
    
    define_singleton_method("decrement_#{value}") do |campaign_id, num|
      redis = Redis.current
      redis.hincrby "moderator:#{campaign_id}", value, -num
    end
    
    define_singleton_method("#{value}") do |campaign_id|
      redis = Redis.current
      redis.hmget "moderator:#{campaign_id}", value      
    end
  end
  
  def self.add_caller_status(caller_id, status)
    redis = Redis.current 
    redis.hset "moderator:#{campaign_id}" "caller:#{caller_id}", status
    redis.publish "event", "moderator:#{campaign_id}"
  end
  
  def self.remove_caller(caller_id)
    redis = Redis.current 
    redis.hdel "moderator:#{campaign_id}" "caller:#{caller_id}"   
  end
  
  
   
end