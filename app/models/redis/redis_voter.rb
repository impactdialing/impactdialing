class RedisVoter
  
  def self.update_voter_with_attempt(voter_id, attempt_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "voter:#{voter_id}", "last_call_attempt", attempt_id 
      redis.hset "voter:#{voter_id}", "last_call_attempt_time", Time.now       
      redis.hset "voter:#{voter_id}", "caller_session_id", caller_session_id      
      redis.hset "voter:#{voter_id}", "status", CallAttempt::Status::RINGING
    end
  end
  
  def self.abandon_call(voter_id)
    redis = RedisConnection.call_flow_connection
    redis.pipelined do
      redis.hset "voter:#{voter_id}", "status", CallAttempt::Status::ABANDONED
      redis.hset "voter:#{voter_id}", "call_back", false
      redis.hset "voter:#{voter_id}", "caller_session", nil
      redis.hset "voter:#{voter_id}", "caller_id", nil      
    end
  end
  
  def self.assigned_to_caller?(voter_id)
    redis = RedisConnection.call_flow_connection
    redis.hexists "voter:#{voter_id}", "caller_session_id"
  end
  
  def self.assign_to_caller(voter_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.hset "voter:#{voter_id}", "caller_session_id" caller_session_id
  end
  
end