class RedisCallMysql
  
  def self.call_completed(call_attempt_id)
    redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
    update_call_attempt(call_attempt_id)
    update_voter(redis_call_attempt['voter_id'])
  end
  
  def self.update_call_attempt(call_attempt_id)
    call_attempt = CallAttempt.find(call_attempt_id)
    redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
    call_attempt.update_attributes(redis_call_attempt)
    RedisCallAttempt.delete(call_attempt_id)
  end
  
  def self.update_voter(voter_id)
    voter = Voter.find(voter_id)
    redis_voter = RedisVoter.read(voter_id)
    puts redis_voter
    begin
      voter.update_attributes(redis_voter)
    rescue ActiveRecord::StaleObjectError => e
      RedisConnection.common_connection.rpush('connected_call_notification', {identity: voter.id, event: "update_voter"}.to_json)
    end
    RedisVoter.delete(voter_id)
  end
  
  def self.update_caller_session(caller_session_id)
    caller_session = CallerSession.find(caller_session_id)
    redis_caller_session = RedisCallerSession.read(caller_session_id)
    begin      
      caller_session.update_attributes(redis_caller_session)
    rescue ActiveRecord::StaleObjectError => e
      RedisConnection.common_connection.rpush('connected_call_notification', {identity: caller_session.id, event: "update_caller_session"}.to_json)
    end
    RedisCallerSession.delete(caller_session.id)  
  end
  
  
end