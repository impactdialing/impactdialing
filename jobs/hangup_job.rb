require 'em-http-request'

class HangupJob 
  @queue = :hangup_job
  
   def self.perform(call_attempt_id, event)    
     call_attempt = CallAttempt.find(call_attempt_id)
     call_attempt.end_running_call
   end
end