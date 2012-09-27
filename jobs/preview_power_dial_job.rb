class PreviewPowerDialJob
  @queue = :call_flow
  
  def self.perform(caller_session_id, voter_id)    
    caller_session = CallerSession.find(caller_session_id)
    voter_info = RedisVoter.read(voter_id)
    begin
      Twillio.dial(voter_info, caller_session)
    rescue ActiveRecord::StaleObjectError 
      caller_session.redirect_caller
    end
  end
end