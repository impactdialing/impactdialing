RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

loop do
  begin
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
    
  rescue Exception => e
  end
end