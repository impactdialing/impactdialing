require 'resque/plugins/lock'
require 'resque-loner'

class DebiterJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :debit_worker_job

   def self.perform     
     begin         
       call_attempts = CallAttempt.debit_not_processed.limit(100) 
       call_attempts.each do |call_attempt|
         call_attempt.debit
         call_attempt.update_attribute(:debited, true)
       end
     
       caller_sessions = CallerSession.debit_not_processed     
       caller_sessions.each do |caller_session|
         caller_session.debit
         caller_session.update_attribute(:debited, true)
       end
     
     rescue Exception => e
       puts e.backtrace
     end      
     
          
   end
end