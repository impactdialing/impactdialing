class RedisCallerSession
  
  def initialize(caller_session_id, session_key, call_sid ,campaign_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "caller_session:#{caller_session_id}", "session_key", session_key 
      redis.hset "caller_session:#{caller_session_id}", "campaign_id", campaign_id
      redis.hset "caller_session:#{caller_session_id}", "sid", call_sid
      redis.hset "caller_session:#{caller_session_id}", "start_time", Time.now
    end
  end
  
  def self.start_conference(caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "caller_session:#{caller_session_id}", "on_call", true 
      redis.hset "caller_session:#{caller_session_id}", "available_for_call", true 
      redis.hset "caller_session:#{caller_session_id}", "attempt_in_progress", nil 
    end
  end
  
  def self.set_attempt_in_progress(caller_session_id, attempt_id)
    redis = RedisConnection.call_flow_connection
    redis.hset "caller_session:#{caller_session_id}", "attempt_in_progress", attempt_id 
  end
  
  def self.end_session(caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.hset "caller_session:#{caller_session_id}", "end_time", Time.now         
  end
  
end