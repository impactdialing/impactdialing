class PersistAnsweredByMachineCalls
  
  def perform
    wrapped_up_calls = RedisCall.push_to_wrapped_up_call_list.range(0,100)
    voters = []
    call_attempts = []
    calls = []
    wrapped_up_calls.each do |wrapped_up_call|
      call_attempt = CallAttempt.find(wrapped_up_call['id'])
      voter = call_attempt.voter
      call_attempts << call_attempt.wrapup_now(wrapped_up_call['current_time'], wrapped_up_call['caller_type'])
    end
    CallAttempt.import call_attempts
  end
  
end