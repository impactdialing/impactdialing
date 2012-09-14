require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class CalculateDialsJob 
  @queue = :calculate_dials_worker


   def self.perform(campaign_id)
     campaign = Campaign.find(campaign_id)
     num_to_call = campaign.number_of_voters_to_dial
     Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"    
     return if num_to_call <= 0    
     campaign.set_calls_in_progress
     voters_to_dial = campaign.choose_voters_to_dial(num_to_call).collect {|voter| voter.id}
     
     voters_to_dial.each_slice(10).to_a.each {|voters| Resque.enqueue(DialerJob, campaign.id, voters_to_dial) }     
   end
end
