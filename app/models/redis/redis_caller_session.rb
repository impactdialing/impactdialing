class RedisCallerSession
  include Redis::Objects
  
  def self.load_caller_session_info(caller_session_id, caller_session)
    caller_session(caller_session_id).bulk_set(caller_session.attributes.to_options)
  end
  
  def self.read(caller_session_id)
    caller_session(caller_session_id).all    
  end
  
  def self.caller_session(caller_session_id)
    redis = RedisConnection.call_flow_connection
    Redis::HashKey.new("caller_session:#{caller_session_id}", redis)    
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