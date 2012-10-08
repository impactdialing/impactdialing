class PersistDisconnectedCallList
  
  def perform
    disconnected_calls = RedisCall.disconnected_call_list.range(0,100)
    
    voters = []
    call_attempts = []
    calls = []
    disconnected_calls.each do |disconnected_call|
      call = Call.find(disconnected_call['id'])
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempts << call_attempt.disconnect_call(disconnected_call['current_time'], disconnected_call['recording_duration'], disconnected_call['recording_url'] )
      voters << voter.disconnect_call(disconnected_call['current_time'])
    end
    Voter.import voters
    CallAttempt.import call_attempts
    
    
  end
end