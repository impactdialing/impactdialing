require 'resque/plugins/lock'
require 'resque-loner'

class AnsweredJob 
  include Resque::Plugins::UniqueJob
  @queue = :answered_worker_job
  
   def self.perform     
     CallAttempt.results_not_processed.where('call_id IS NOT NULL').includes(:call).limit(1000).each do |call_attempt|
       begin
         questions = RedisCall.questions(call_attempt.call.id)
         notes = RedisCall.notes(call_attempt.call.id)
         call_attempt.voter.persist_answers(questions, call_attempt)
         call_attempt.voter.persist_notes(notes, call_attempt)
         call_attempt.update_attributes(voter_response_processed: true)
         call_attempt.voter.update_attribute(:result_date, Time.now)
         RedisCall.delete(call_attempt.call.id)
       rescue Exception => e
         call_attempt.update_attributes(voter_response_processed: true)         
         puts e.backtrace
       end      
    end    
   end
end
