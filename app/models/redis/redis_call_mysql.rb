class RedisCallMysql
  
  def self.call_completed(call_attempt_id)
    redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
    update_call_attempt(call_attempt_id)
    update_voter(redis_call_attempt['voter_id'])
    # update_caller_session(redis_call_attempt['caller_session_id'])
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
    voter.update_attributes(redis_voter)
    RedisVoter.delete(voter_id)
  end
  
  def self.update_caller_session(caller_session_id)
    caller_session = CallerSession.find(caller_session_id)
    redis_caller_session = RedisCallerSession.find(caller_session_id)
    caller_session.update_attributes(redis_caller_session)  
  end
  
  
end