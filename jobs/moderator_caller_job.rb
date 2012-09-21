require 'em-http-request'

class ModeratorCallerJob 
  Resque::Plugins::Timeout.timeout = 10  
  @queue = :moderator_caller_job
  
   def self.perform(caller_session_id, event)    
     caller_session = CallerSession.find(caller_session_id)
     caller_session.send(event)
   end
end