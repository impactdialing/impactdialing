require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id)
     campaign = Campaign.find(campaign_id)
     num_to_call = campaign.number_of_voters_to_dial
     Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"    
     return if num_to_call <= 0    
     campaign.set_calls_in_progress     
     begin
       EM.synchrony do
         concurrency = 8
         voters_to_dial = campaign.choose_voters_to_dial(nums_to_call)
         EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
           voter.dial_predictive_em(iter)
         end
         Resque.redis.del("dial:#{campaign.id}")
         EventMachine.stop
       end
      rescue Exception => e
        EventMachine.stop
        puts e        
      end
   end
end
