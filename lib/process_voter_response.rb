RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

loop do
  begin
    CallAttempt.results_not_processed.find_in_batches(batch_size: 10) do |call_attempts|
      call_attempts.each do |call_attempt|
        call_attempt.voter.persist_answers(call_attempt.call.questions, call_attempt)
        call_attempt.voter.persist_notes(call_attempt.call.notes)
        call_attempt.update_attribute(:voter_response_processed, true)
        call_attempt.voter.update_attribute(:result_date, Time.now)
      end
    end
  rescue Exception => e
  end
end