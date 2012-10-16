class CallerPusherJob 
  include Sidekiq::Worker
  sidekiq_options :retry => false
  
   def perform(caller_session_id, event)    
     caller_session = CallerSession.find(caller_session_id)
     caller_session.send(event)
   end
end
