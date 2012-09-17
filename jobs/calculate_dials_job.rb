require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'resque/plugins/lock'
require 'resque-loner'


class CalculateDialsJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  
  @queue = :calculate_dials_worker


   def self.perform(campaign_id)
     campaign = Campaign.find(campaign_id)
     num_to_call = campaign.number_of_voters_to_dial - campaign.dialing_count
     Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"    
     return if num_to_call <= 0    
     voters_to_dial = campaign.choose_voters_to_dial(num_to_call).collect {|voter| voter.id}
     campaign.increment_campaign_dial_count(voters_to_dial.size)
     if voters_to_dial.size <=10
       Dial.perform(campaign_id, voters_to_dial)
     else
       voters_to_dial.each_slice(10).to_a.each {|voters| Resque.enqueue(DialerJob, campaign.id, voters) }     
     end                    
   end
end
