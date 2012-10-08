class PersistAnsweredByMachineCalls
  
  def perform
    unanswered_calls = RedisCall.end_answered_by_machine_call_list.range(0,100)
    voters = []
    call_attempts = []
    calls = []
    unanswered_calls.each do |unanswered_call|
      call = Call.find(unanswered_call['id'])
      connect_time = RedisCall.processing_by_machine_call_hash[unanswered_call['id']]
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << call_attempt.end_answered_by_machine(connect_time, unanswered_call['current_time'])
      voters << voter.end_answered_by_machine
    end
    Voter.import voters
    CallAttempt.import call_attempts
  end
  
end