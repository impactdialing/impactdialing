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
     
    #  session_results = []
    # caller_sessions = CallerSession.debit_not_processed.limit(1000)     
    # caller_sessions.each do |caller_session|
    #   begin
    #     session_results << caller_session.debit
    #    rescue Exception=>e
    #      puts e
    #    end
    # end
    # CallerSession.import session_results, :on_duplicate_key_update=>[:debited, :payment_id]
   end
end