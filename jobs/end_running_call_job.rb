class EndRunningCallJob 
  include Sidekiq::Worker
  @queue = :call_flow
  
   def self.perform(call_sid)
     t = TwilioLib.new    
     t.end_call_sync(call_sid)              
   end
end