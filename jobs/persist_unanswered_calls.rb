class PersistUnansweredCalls
  
  def perform
    unanswered_calls = RedisCall.not_answered_call_list.range(0,100)
    voters = []
    call_attempts = []
    calls = []
    unanswered_calls.each do |unanswered_call|
      call = Call.find(unanswered_call['id'])
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << update_call_attempt(call_attempt)
      voters << update_voter(voter)
    end
    Voter.import voters
    CallAttempt.import call_attempts
  end
  
  def update_voter(voter, unanswered_call)
    voter.status = CallAttempt::Status::MAP[unanswered_call['call_status']]
    voter.last_call_attempt_time = unanswered_call['end_time']
    voter.call_back = false    
    voter
  end
  
  def update_call_attempt(call_attempt, unanswered_call)
    call_attempt.status = CallAttempt::Status::MAP[unanswered_call['call_status']]
    call_attempt.call_end = unanswered_call['end_time']
    call_attempt.wrapup_time = unanswered_call['end_time']    
    call_attempt
  end
  
end