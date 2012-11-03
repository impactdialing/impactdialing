class EndCallerSessionJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  
   def perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     caller_id = caller_session.caller_id
     Voter.where(campaign_id: caller_session.caller.campaign_id, caller_id: caller_id, status: CallAttempt::Status::READY).update_all(status: 'not called')
     CallAttempt.wrapup_calls(caller_id)
   end
end
