require 'resque/plugins/lock'
class AnsweredJob 
  extend Resque::Plugins::Lock
  @queue = :answered
  
   def self.perform(campaign_id)     
     campaign = Campaign.find(campaign_id)
     campaign.call_attempts.results_not_processed.limit(10).each do |call_attempt|
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