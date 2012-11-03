require 'resque-loner'

class PhantomCallerJob 
  include Resque::Plugins::UniqueJob
  @queue = :background_worker
  
   def self.perform
     t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
     CallerSession.on_call.where("updated_at < ? ", 5.minutes.ago).each do |cs|              
       begin
         if cs.sid.starts_with?("CA")
           call_response = Hash.from_xml(t.call("GET", "Calls/" + cs.sid, {}))['TwilioResponse']['Call']
           cs.end_running_call if call_response.try(:[],"Status") == 'completed'
         end
        rescue
          puts cs.id
        end
     end
     RedisCallerSession.phantom_callers.each do |cs|
       caller_session = CallerSession.find(cs)
       caller_session.end_running_call
       RedisCallerSession.remove_phantom_caller(cs)
     end
   end
end