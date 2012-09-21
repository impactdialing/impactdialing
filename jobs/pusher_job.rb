class PusherJob 
  @queue = :pusher_job
  
   def self.perform(call_attempt_id, event)    
     call_attempt = CallAttempt.find(call_attempt_id)
     call_attempt.send(event)
   end
end