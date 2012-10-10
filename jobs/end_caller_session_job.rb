class EndCallerSessionJob
  include Sidekiq::Worker
  
   def perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     campaign = caller_session.campaign
     caller = caller_session.caller
     voters = Voter.find_all_by_caller_id_and_status(caller.id, CallAttempt::Status::READY)
     Voter.transaction do
       voters.each {|voter| voter.update_attributes(status: 'not called')}    
     end
     CallAttempt.wrapup_calls(caller.id)
   end
end