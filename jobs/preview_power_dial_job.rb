class PreviewPowerDialJob
  @queue = :call_flow
  
  def self.perform(caller_session_id, voter_id)    
    caller_session = CallerSession.find(caller_session_id)
    caller_session.dial(Voter.find(voter_id)) 
  end
end