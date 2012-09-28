class EndCallerSessionJob
  @queue = :call_flow
  
   def self.perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     campaign = caller_session.campaign
     caller = caller_session.caller
     voters = Voter.find_all_by_caller_id_and_status(caller.id, CallAttempt::Status::READY)
     Voter.transaction do
       voters.each {|voter| voter.update_attributes(status: 'not called')}    
     end
     CallAttempt.wrapup_calls(caller.id)

     Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => caller_session.id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
     :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})     
   end
end