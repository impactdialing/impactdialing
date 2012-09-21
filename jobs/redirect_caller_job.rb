require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class RedirectCallerJob 
  @queue = :redirect_caller_job
  
   def self.perform(call_attempt_id)    
     call_attempt = CallAttempt.find(call_attempt_id)
     call_attempt.redirect_caller
   end
end