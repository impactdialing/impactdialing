class RedisCallAttempt
  
  def initialize(call_attempt_id, voter_id, campaign_id, dialer_mode, caller_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "call_attempt:#{call_attempt_id}", "voter_id", voter_id
      redis.hset "call_attempt:#{call_attempt_id}", "campaign_id", campaign_id
      redis.hset "call_attempt:#{call_attempt_id}", "dialer_mode", dialer_mode
      redis.hset "call_attempt:#{call_attempt_id}", "status", CallAttempt::Status::RINGING             
      redis.hset "call_attempt:#{call_attempt_id}", "caller_id", caller_id
      redis.hset "call_attempt:#{call_attempt_id}", "call_start", Time.now                                
    end
  end
  
  def self.connect_call(call_attempt_id, caller_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "call_attempt:#{call_attempt_id}", "status", CallAttempt::Status::INPROGRESS
      redis.hset "call_attempt:#{call_attempt_id}", "connecttime", Time.now              
      redis.hset "call_attempt:#{call_attempt_id}", "caller_id", caller_id                    
      redis.hset "call_attempt:#{call_attempt_id}", "caller_session_id", caller_session_id      
    end    
  end
  
  def self.abandon_call(call_attempt_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "call_attempt:#{call_attempt_id}", "status", CallAttempt::Status::ABANDONED
      redis.hset "call_attempt:#{call_attempt_id}", "connecttime", Time.now
      redis.hset "call_attempt:#{call_attempt_id}", "wrapup_time", Time.now
    end        
  end
  
  def self.connect_time(call_attempt_id)
    redis = RedisConnection.call_flow_connection
    redis.hget "call_attempt:#{call_attempt_id}", "connecttime"
  end
  
  def self.call_attempt(call_attempt_id)
    redis = RedisConnection.call_flow_connection
    redis.hgetall "call_attempt:#{call_attempt_id}"
end