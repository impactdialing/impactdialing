require 'em-http-request'

class CallerPusherJob 
  Resque::Plugins::Timeout.timeout = 2
  @queue = :caller_pusher_job
  
   def self.perform(caller_session_id, event)    
     caller_session = CallerSession.find(caller_session_id)
     caller_session.send(event)
   end
end