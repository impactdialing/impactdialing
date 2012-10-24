require 'resque/plugins/lock'
require 'resque-loner'

class DebiterJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :debit_worker

   def self.perform     
     call_results = []
     call_attempts = CallAttempt.debit_not_processed.limit(1000)        
     call_attempts.each do |call_attempt|
       begin
         call_results << call_attempt.debit         
       rescue Exception => e
         puts e
       end
     end
     CallAttempt.import call_results, :on_duplicate_key_update=>[:debited, :payment_id]
     
     webui_session_results = []
     web_caller_sessions = WebuiCallerSession.debit_not_processed.limit(100)     
     web_caller_sessions.each do |caller_session|
       begin
        webui_session_results << caller_session.debit
       rescue Exception=>e
         puts e
       end
     end
     WebuiCallerSession.import webui_session_results, :on_duplicate_key_update=>[:debited, :payment_id]
     
     phones_session_results = []
     phones_caller_sessions = PhonesOnlyCallerSession.debit_not_processed.limit(5000)     
     phones_caller_sessions.each do |caller_session|
       begin
        phones_session_results << caller_session.debit
       rescue Exception=>e
         puts e
       end
     end
     PhonesOnlyCallerSession.import phones_session_results, :on_duplicate_key_update=>[:debited, :payment_id]
     
     
   end
end
