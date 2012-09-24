class RedirectCallerJob 
  @queue = :redirect_caller_job
  
   def self.perform(caller_session_id)    
     caller_session = CallerSession.find(caller_session_id)
     caller_session.redirect_caller     
   end
end