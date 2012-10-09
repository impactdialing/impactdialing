class CampaignStatusJob 
  include Sidekiq::Worker
  include SidekiqEvents
  
   def perform(event, campaign_id, call_attempt_id, caller_session_id)
     send(event, campaign_id, call_attempt_id, caller_session_id)
     enqueue_monitor_campaign_flow(MonitorCampaignJob, [campaign_id])               
   end
   
   def dialing(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.add_to_ringing(campaign_id, call_attempt_id)     
   end
   
   def failed(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_ringing_to_completed(campaign_id, call_attempt_id)
   end
   
   def connected(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_ringing_to_inprogress(campaign_id, call_attempt_id);
     RedisCaller.move_on_hold_to_on_call(campaign_id, caller_session_id)
     enqueue_monitor_caller_flow(MonitorCallerJob, [campaign_id, caller_session_id, "On call", "update"])
   end
   
   def disconnected(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_inprogress_to_wrapup(campaign_id, call_attempt_id);
     RedisCaller.move_on_call_to_on_wrapup(campaign_id, caller_session_id)
     enqueue_monitor_caller_flow(MonitorCallerJob, [campaign_id, caller_session_id, "Wrap up", "update"])
   end
   
   def abandoned(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_ringing_to_abandoned(campaign_id, call_attempt_id); 
   end
   
   def answered_machine(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_ringing_to_completed(campaign_id, call_attempt_id);
   end
   
   def wrapped_up(campaign_id, call_attempt_id, caller_session_id)
     RedisCampaignCall.move_wrapup_to_completed(campaign_id, call_attempt_id); 
     enqueue_monitor_caller_flow(MonitorCallerJob, [campaign_id, caller_session_id, "On hold", "update"])     
   end
   
   def on_hold(campaign_id, call_attempt_id, caller_session_id)
     RedisCaller.move_to_on_hold(campaign_id, caller_session_id)
   end
   
   def caller_connected(campaign_id, call_attempt_id, caller_session_id)
     RedisCaller.add_caller(campaign_id, caller_session_id)
     enqueue_monitor_caller_flow(MonitorCallerJob, [campaign_id, caller_session_id, "caller_connected", "new"])
   end
   
   def caller_disconnected(campaign_id, call_attempt_id, caller_session_id)
     RedisCaller.disconnect_caller(campaign_id, caller_session_id)
     enqueue_monitor_caller_flow(MonitorCallerJob, [campaign_id, caller_session_id, "caller_disconnected", "delete"])
   end
   
   
end