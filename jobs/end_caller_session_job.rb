class EndCallerSessionJob
  include Sidekiq::Worker
  
   def perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     caller_id = caller_session.caller_id
     Voter.where(caller_id: caller_id, status: CallAttempt::Status::READY).update_all(status: 'not called')
     CallAttempt.wrapup_calls(caller_id)
   end
end
