require 'resque/plugins/lock'
require 'resque-loner'

class DebiterJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :debit_worker

   def self.perform     
     call_attempts = CallAttempt.debit_not_processed.limit(1000)        
     call_attempts.each do |call_attempt|
       begin
         call_attempt.debit
       rescue Exception => e
         puts "eeee"
       end
     end
     
    caller_sessions = CallerSession.debit_not_processed.limit(1000)     
    caller_sessions.each do |caller_session|
      begin
        caller_session.debit
       rescue Exception=>e
       end
    end
   end
end