class PreviewPowerDialJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  
  def perform(caller_session_id, voter_id)    
    caller_session = CallerSession.find(caller_session_id)
    voter = Voter.find(voter_id)
    begin
      Twillio.dial(voter, caller_session)
    rescue ActiveRecord::StaleObjectError 
      caller_session.redirect_caller
    end
  end
end