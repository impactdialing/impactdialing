RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

loop do
  begin
    CallAttempt.results_not_processed.limit(10).each do |call_attempt|
      call_attempt.voter.persist_answers(call_attempt.call.questions, call_attempt)
      call_attempt.voter.persist_notes(call_attempt.call.notes)
      call_attempt.update_attributes(voter_response_processed: true)
      call_attempt.voter.update_attribute(:result_date, Time.now)
    end
  rescue Exception => e
    puts e.backtrace
  end
end