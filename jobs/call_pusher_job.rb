class CallPusherJob 
  include Sidekiq::Worker
  
   def perform(call_attempt_id, event)    
     call_attempt = CallAttempt.find(call_attempt_id)
     call_attempt.send(event)
   end
end