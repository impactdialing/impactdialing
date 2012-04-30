RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

loop do
  begin
    call_attempts = CallAttempt.results_not_processed
    call_attempts.each do |call_attempt|
      call_attempt.voter.persist_answers(call_attempt.call.questions, call_attempt)
      call_attempt.voter.persist_notes(call_attempt.call.notes)
      call_attempt.update_attributes(voter_response_processed: true, result_date: Time.now)
    end
    
  rescue Exception => e
  end
end