class PreviewPowerDialJob
  include Sidekiq::Worker
  
  def perform(caller_session_id, voter_id)    
    caller_session = CallerSession.find(caller_session_id)
    begin
      caller_session.dial(Voter.find(voter_id)) 
    rescue ActiveRecord::StaleObjectError 
      caller_session.redirect_caller
    end
  end
end