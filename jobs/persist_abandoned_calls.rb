class PersistAnsweredUnattendedCalls
  
  def perform
    abandoned_calls = RedisCall.abandoned_call_list.range(0,100)
    voters = []
    call_attempts = []
    calls = []
    abandoned_calls.each do |abandoned_call|
      call = Call.find(abandoned_call['id'])
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << call_attempt.abandoned(abandon_call['current_time'])
      voters << voter.abandoned(abandon_call['current_time'])
    end
    Voter.import voters
    CallAttempt.import call_attempts
  end
  
end