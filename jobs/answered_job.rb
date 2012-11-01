require 'resque/plugins/lock'
require 'resque-loner'

class AnsweredJob
  include Resque::Plugins::UniqueJob
  @queue = :answered_worker_job

   def self.perform
     success_count = 0
     not_found = 0
     CallAttempt.results_not_processed.where('call_id IS NOT NULL').reorder('call_attempts.id DESC').includes(:call).find_each do |call_attempt|
       begin
         call = call_attempt.call
         answers_data = RedisCall.questions_and_notes(call.id)
         if answers_data
           questions = answers_data["questions"]
           notes = answers_data["notes"]
           call_attempt.voter.persist_answers(questions, call_attempt)
           call_attempt.voter.persist_notes(notes, call_attempt)
           call_attempt.update_attributes(voter_response_processed: true)
           call_attempt.voter.update_attribute(:result_date, Time.now)
           RedisCall.delete(call.id)
           success_count += 1
         else
           if call_attempt.created_at < 1.day.ago
             call_attempt.update_column(voter_response_processed: true)
           else
             not_found += 1
           end
         end
       rescue Exception => e
         puts 'Answered Job Exception: ' + e.to_s
         puts e.backtrace
       end
     end
     puts "Answered Job: processed: #{success_count}"
     puts "Answered Job: not found: #{not_found}"
   end
end
