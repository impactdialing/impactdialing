require Rails.root.join("lib/redis_connection")
class MonitorCampaign
  
  def initialize(campaign_id, num_callers_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, 
    num_available, num_remaining)
    campaign = Campaign.find(campaign_id)
    redis = RedisConnection.monitor_connection
    redis.hset "monitor_campaign:#{campaign_id}", "timestamp", Time.now
    redis.hset "monitor_campaign:#{campaign_id}", "name", campaign.name
    redis.hset "monitor_campaign:#{campaign_id}", "id", campaign.id
    redis.hdel  "monitor_campaign:#{campaign_id}", "callers_logged_in"
    redis.hdel  "monitor_campaign:#{campaign_id}", "on_call"
    redis.hdel  "monitor_campaign:#{campaign_id}", "on_hold"
    redis.hdel  "monitor_campaign:#{campaign_id}", "ringing_lines"
    redis.hdel  "monitor_campaign:#{campaign_id}", "wrapup"
    redis.hdel  "monitor_campaign:#{campaign_id}", "live_lines"
    redis.hdel  "monitor_campaign:#{campaign_id}", "available"
    redis.hdel  "monitor_campaign:#{campaign_id}", "remaining"    
    
    redis.hincrby "monitor_campaign:#{campaign_id}", "callers_logged_in", num_callers_logged_in
    redis.hincrby "monitor_campaign:#{campaign_id}", "on_call", num_on_call
    redis.hincrby "monitor_campaign:#{campaign_id}", "on_hold", num_on_hold
    redis.hincrby "monitor_campaign:#{campaign_id}", "ringing_lines", num_ringing_lines    
    redis.hincrby "monitor_campaign:#{campaign_id}", "wrapup", num_wrapup    
    redis.hincrby "monitor_campaign:#{campaign_id}", "live_lines", num_live_lines        
    redis.hincrby "monitor_campaign:#{campaign_id}", "available", num_available        
    redis.hincrby "monitor_campaign:#{campaign_id}", "remaining", num_remaining            
    redis.zadd("monitoring", Time.now.to_i,  "monitor_campaign:#{campaign_id}")
  end
  
  ['callers_logged_in', 'on_call', 'on_hold', 'wrapup', 'live_lines', 'ringing_lines', 'available', 'remaining' ].each do |value|
    define_singleton_method("increment_#{value}") do |campaign_id, num|
      redis = RedisConnection.monitor_connection
      redis.hincrby "monitor_campaign:#{campaign_id}", value, num
    end
    
    define_singleton_method("decrement_#{value}") do |campaign_id, num|
      redis = RedisConnection.monitor_connection
      redis.hincrby "monitor_campaign:#{campaign_id}", value, -num
    end
    
    define_singleton_method("#{value}") do |campaign_id|
      redis = RedisConnection.monitor_connection
      redis.hmget("monitor_campaign:#{campaign_id}", value)[0]
    end
  end
  
  def self.name(campaign_id)
    redis = RedisConnection.monitor_connection
    redis.hmget("monitor_campaign:#{campaign_id}", 'name')[0]    
  end
  
  def self.add_caller_status(caller_id, status)
    redis = RedisConnection.monitor_connection 
    redis.hset "monitor_campaign:#{campaign_id}" "caller:#{caller_id}", status
  end
  
  def self.remove_caller(caller_id)
    redis = RedisConnection.monitor_connection 
    redis.hdel "monitor_campaign:#{campaign_id}" "caller:#{caller_id}"   
  end
  
  def self.campaign_overview_info(campaign)
    num_logged_in = campaign.caller_sessions.on_call.size
    num_on_call = campaign.caller_sessions.not_available.size
    num_wrapup = campaign.call_attempts.not_wrapped_up.between(3.minutes.ago, Time.now).size
    num_on_hold = campaign.caller_sessions.available.size
    num_live_lines = campaign.call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::INPROGRESS).size
    num_ringing_lines = campaign.call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    num_remaining = campaign.all_voters.by_status('not called').count
    num_available = num_voter_available(campaign) + num_remaining
    [num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining]
  end
  
  def self.num_voter_available(campaign)
    voters_available_for_retry = campaign.all_voters.enabled.avialable_to_be_retried(campaign.recycle_rate).count
    scheduled_for_now = campaign.all_voters.scheduled.count
    abandoned_count = campaign.all_voters.by_status(CallAttempt::Status::ABANDONED).count
    sanitize_dials(voters_available_for_retry + scheduled_for_now + abandoned_count)
  end
  
  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
  
  
  
   
end