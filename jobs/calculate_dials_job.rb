require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class CalculateDialsJob 
  @queue = :calculate_dials_worker


   def self.perform(campaign_id)
     campaign = Campaign.find(campaign_id)
     num_to_call = campaign.number_of_voters_to_dial
     Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"    
     if num_to_call <= 0    
       Resque.redis.del("dial_count:#{campaign.id}")
       return
     end
     voters_to_dial = campaign.choose_voters_to_dial(num_to_call).collect {|voter| voter.id}          
     campaign.increment_campaign_dial_count(voters_to_dial.size - 1)
     voters_to_dial.each_slice(10).to_a.each {|voters| Resque.enqueue(DialerJob, campaign.id, voters) }     
   end
end
