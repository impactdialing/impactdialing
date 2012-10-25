class RedirectCallerJob 
  include Sidekiq::Worker
  sidekiq_options :retry => false
  
   def perform(caller_session_id)    
     caller_session = CallerSession.find_by_id_cached(caller_session_id)
     caller_session.redirect_caller     
   end
end