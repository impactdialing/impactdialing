require Rails.root.join("jobs/heroku_resque_answered_auto_scale")
require 'resque/plugins/lock'
require 'resque-loner'
class AnsweredJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  extend ::HerokuResqueAnsweredAutoScale
  @queue = :answered_worker
  
   def self.perform     
     CallAttempt.results_not_processed.limit(100).each do |call_attempt|
       begin
         call_attempt.voter.persist_answers(call_attempt.call.questions, call_attempt)
         call_attempt.voter.persist_notes(call_attempt.call.notes, call_attempt)
         call_attempt.update_attributes(voter_response_processed: true)
         call_attempt.voter.update_attribute(:result_date, Time.now)
       rescue Exception => e
         puts e.backtrace
       end      
    end    
   end
end