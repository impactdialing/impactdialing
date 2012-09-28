require 'octopus'
require 'resque-loner'

class SimulatorJob 
  @queue = :simulator
  include Resque::Plugins::UniqueJob

   def self.perform(campaign_id)
    begin 
     target_abandonment = Campaign.using(:read_slave1).find(campaign_id).acceptable_abandon_rate
     start_time = 60 * 10
     simulator_length = 60 * 60
     abandon_count = 0
     dials_needed = 1
     best_dials = 1  
     increment = 10.0
     outer_loop = 0
     inner_loop = 0

     expected_conversation, longest_conversation, best_conversation, mean_conversation, expected_wrapup_time, longest_wrapup_time, best_wrapup_time, caller_statuses, observed_conversations, observed_dials =  simulator_campaign_base_values(campaign_id, start_time)

     while outer_loop < 3
       best_utilization = 0
       if outer_loop == 1
         expected_conversation = mean_conversation
       end

       if outer_loop == 2
         expected_wrapup_time = 0
       end        

       while inner_loop < increment
         idle_time = active_time = 0.0 
         t = 0
         active_dials =  []
         finished_dials = []
         active_conversations = []
         finished_conversations = []

         while(t <= simulator_length)  

           active_conversations.clone.each do |call_attempt|
             if call_attempt.counter == call_attempt.length
               caller_statuses.detect(&:unavailable?).toggle
               finished_conversations << call_attempt
               active_conversations.delete(call_attempt)
               call_attempt.counter = 0
             else
               call_attempt.counter += 1
             end
           end


           active_dials.clone.each do |dial|
             if dial.counter == dial.length
               if dial.answered?
                 if status = caller_statuses.detect(&:available?)
                   status.toggle
                   active_conversations << observed_conversations[rand(observed_conversations.size)]
                 else
                   abandon_count += 1
                 end
               end
               finished_dials << dial
               active_dials.delete(dial)
               dial.counter = 0
             else
               dial.counter += 1
             end
           end

           active_wrapups = []
           active_conversations.each do |active_conversation| 
              if active_conversation.counter > active_conversation.length
                active_wrapups <<  (active_conversation.counter - active_conversation.length)
              end
           end               

           available_callers = caller_statuses.count(&:available?) + 
                             active_conversations.count{|active_conversation| (active_conversation.counter > expected_conversation) && (active_conversation.counter < longest_conversation)} +
                             active_wrapups.count{|active_wrapup| (active_wrapup > expected_wrapup_time)}          

           ringing_lines = active_dials.length
           dials_to_make = (( dials_needed * available_callers ) - ringing_lines).to_i
           dials_to_make.times{ active_dials << observed_dials[rand(observed_dials.size)] }
           idle_time += caller_statuses.select(&:available?).size
           active_time += caller_statuses.select(&:unavailable?).size
           finished_dials.each{|dial| dial.counter += 1}
           finished_conversations.each{|call_attempt| call_attempt.counter += 1}
           t += 1     

        end

        finished_conversations_answered_count = finished_conversations.count(&:answered?)
        simulated_abandonment = abandon_count / (finished_conversations_answered_count == 0 ? 1 : finished_conversations_answered_count)

        if simulated_abandonment <= target_abandonment     
          utilization = active_time / ( active_time + idle_time )     
          if utilization > best_utilization
            best_utilization = utilization
            best_dials = dials_needed if outer_loop == 0
            best_conversation = expected_conversation if outer_loop == 1
            best_wrapup_time = expected_wrapup_time if outer_loop == 2
          end
        end   
        answered_observed_dials = observed_dials.count(&:answered?)
        answer_ratio =  answered_observed_dials == 0 ? 1 : (observed_dials.size  / answered_observed_dials)
       if outer_loop == 0
         dials_needed += (answer_ratio - 1)/ increment
       end

       if outer_loop == 1
         expected_conversation += ((longest_conversation - mean_conversation) /increment)
       end

       if outer_loop == 2
         expected_wrapup_time += (longest_wrapup_time/increment)
       end

       inner_loop += 1
     end  
       dials_needed = best_dials
       expected_conversation = best_conversation
       expected_wrapup_time = best_wrapup_time
       outer_loop += 1
    end
    puts "Simulated_#{campaign_id} , Lines To Dial: #{best_dials}, Expected Call Time: #{best_conversation}, Expected Wrapup Time: #{best_wrapup_time} "
    SimulatedValues.find_or_create_by_campaign_id(campaign_id).update_attributes(best_dials: best_dials, best_conversation: best_conversation, longest_conversation: longest_conversation, best_wrapup_time: best_wrapup_time)
   rescue Exception => e
   end  
     
   end
   
   
   
   def self.simulator_campaign_base_values(campaign_id, start_time)
       Octopus.using(:read_slave1) do
         caller_statuses = CallerSession.where(:campaign_id => campaign_id,
                   :on_call => true).size.times.map{ CallerStatus.new('available') }            
               
         campaign = Campaign.find(campaign_id)

         number_of_call_attempts = campaign.call_attempts.between((Time.now - start_time.seconds), Time.now).size
         call_attempts_from_start_time = campaign.call_attempts.between((Time.now - start_time.seconds), Time.now).limit(1000)

         puts "Simulating #{call_attempts_from_start_time.size} call attempts"
         observed_conversations = call_attempts_from_start_time.select{|ca| ca.status == "Call completed with success."}.map{|attempt| OpenStruct.new(:length => attempt.duration_wrapped_up, time_to_wrapup: attempt.time_to_wrapup, :counter => 0)}
         observed_dials = call_attempts_from_start_time.map{|attempt| OpenStruct.new(:length => attempt.ringing_duration, :counter => 0, :answered? => attempt.status == 'Call completed with success.') }
         ActiveRecord::Base.logger.info observed_conversations

         unless observed_conversations.blank?
           mean_conversation = average(observed_conversations.map(&:length))
           longest_conversation = observed_conversations.max_by{|conv| conv.length}.try(:length)
           longest_wrapup_time = observed_conversations.max_by{|conv| conv.time_to_wrapup}.try(:time_to_wrapup)
         else
           mean_conversation = 0
           longest_conversation = 0
           longest_wrapup_time = 0
         end

         expected_conversation = longest_conversation
         best_conversation = longest_conversation
         best_wrapup_time = longest_wrapup_time
         expected_wrapup_time = longest_wrapup_time
      end
      [expected_conversation, longest_conversation, best_conversation, mean_conversation, expected_wrapup_time, longest_wrapup_time, best_wrapup_time, caller_statuses, observed_conversations, observed_dials]
   end   
   
   
   
end


class CallerSession < ActiveRecord::Base
end

class CallAttempt < ActiveRecord::Base
  def duration
    return nil unless connecttime
    ((wrapup_time || Time.now) - self.connecttime).to_i
  end

  def ringing_duration
    return 15 unless connecttime
    (connecttime - created_at).to_i
  end
end

class SimulatedValues < ActiveRecord::Base
end

class CallerStatus
  attr_accessor :status

  def initialize(status)
    @status = status
  end

  def available?
    @status == 'available'
  end

  def unavailable?
    !available?
  end

  def toggle
    @status = available? ? 'busy' : 'available'
  end
end

def average(array)
  array.sum.to_f / array.size
end
