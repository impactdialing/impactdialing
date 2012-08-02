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
  
  def self.connect_lead_to_caller(voter_id, campaign_id)
    redis = RedisConnection.call_flow_connection
    begin
      unless RedisVoter.assigned_to_caller?(voter.id)
        RedisVoter.assign_to_caller(voter_id, RedisAvailableCaller.longest_waiting_caller(campaign_id))
      end
      if RedisVoter.assigned_to_caller?(voter.id)
        redis.pipelined do
          redis.hset "voter:#{voter_id}", "caller_id", nil      
          redis.hset "voter:#{voter_id}", "status", CallAttempt::Status::INPROGRESS      
        end
        voter.caller_session.reload      
        voter.caller_session.update_attributes(:on_call => true, :available_for_call => false)  
      end
    rescue ActiveRecord::StaleObjectError
      abandon_call
    end    
  end
  
  
end