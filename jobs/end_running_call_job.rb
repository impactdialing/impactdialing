class EndRunningCallJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(call_sid)
     t = TwilioLib.new
     t.end_call_sync(call_sid)
   end
end