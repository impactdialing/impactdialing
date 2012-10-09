class EndRunningCallJob 
  include Sidekiq::Worker
  
   def perform(call_sid)
     t = TwilioLib.new    
     t.end_call_sync(call_sid)              
   end
end