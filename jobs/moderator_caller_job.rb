require 'em-http-request'

class ModeratorCallerJob 
  @queue = :moderator_caller_job
  
   def self.perform(caller_session_id, event)    
     
     caller_session = CallerSession.find(caller_session_id)
     caller_session.send(event)
   end
end