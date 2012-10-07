class PersistAbandonedCalls
  
  def perform
    abandoned_calls = RedisCall.abandoned_call_list.range(0,100)
    voters = []
    call_attempts = []
    calls = []
    abandoned_calls.each do |abandoned_call|
      call = Call.find(abandoned_call['id'])
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << update_call_attempt(call_attempt)
      voters << update_voter(voter)
    end
    Voter.import voters
    CallAttempt.import call_attempts
  end
  
  def update_voter(voter, abandoned_call)
    voter.abandoned
    voter
  end
  
  def update_call_attempt(call_attempt, abandoned_call)
    call_attempt.abandoned(abandon_call['connected_time'])
    call_attempt
  end
  
end