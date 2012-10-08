class PersistUnansweredCalls
  
  def perform
    unanswered_calls = RedisCall.not_answered_call_list.range(0,300)
    voters = []
    call_attempts = []
    calls = []
    unanswered_calls.each do |unanswered_call|
      call = Call.find(unanswered_call['id'])
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << call_attempt.end_unanswered_call(unanswered_call['current_time'], unanswered_call['call_status'])
      voters << voter.end_unanswered_call(unanswered_call['current_time'], unanswered_call['call_status'])
    end
    Voter.import voters
    CallAttempt.import call_attempts
  end
    
end