class ModeratorCampaign
  
  def initialize(campaign_id, num_callers_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines)
    redis = Redis.current
    redis.hdel  "moderator:#{campaign_id}", "callers_logged_in"
    redis.hdel  "moderator:#{campaign_id}", "on_call"
    redis.hdel  "moderator:#{campaign_id}", "on_hold"
    redis.hdel  "moderator:#{campaign_id}", "ringing_lines"
    redis.hdel  "moderator:#{campaign_id}", "wrapup"
    redis.hdel  "moderator:#{campaign_id}", "live_lines"
    
    redis.hincrby "moderator:#{campaign_id}", "callers_logged_in", num_callers_logged_in
    redis.hincrby "moderator:#{campaign_id}", "on_call", num_on_call
    redis.hincrby "moderator:#{campaign_id}", "on_hold", num_on_hold
    redis.hincrby "moderator:#{campaign_id}", "ringing_lines", num_ringing_lines    
    redis.hincrby "moderator:#{campaign_id}", "wrapup", num_wrapup    
    redis.hincrby "moderator:#{campaign_id}", "live_lines", num_live_lines        
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
  
   
end