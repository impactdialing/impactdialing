class EndRunningCallJob 
  @queue = :end_running_call
  
   def self.perform(call_sid)
     t = TwilioLib.new    
     t.end_call_sync(call_sid)              
   end
end