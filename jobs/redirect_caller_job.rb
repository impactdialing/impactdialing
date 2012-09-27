class RedirectCallerJob 
  @queue = :call_flow
  
   def self.perform(caller_session_id)    
     caller_session = CallerSession.find(caller_session_id)
     caller_session.redirect_caller     
   end
end