require 'resque/plugins/lock'
class DebiterJob 
  extend Resque::Plugins::Lock
  @queue = :debiter

   def self.perform
     call_attempts = CallAttempt.debit_not_processed
          
     call_attempts.each do |call_attempt|
       call_attempt.debit
       call_attempt.update_attribute(:debited, true)
     end

     caller_sessions = CallerSession.debit_not_processed
     caller_sessions.each do |caller_session|
       caller_session.debit
       caller_session.update_attribute(:debited, true)
     end
     
   end
end