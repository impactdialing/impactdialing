require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id, voter_ids)
     campaign = Campaign.find(campaign_id)     
     voters_to_dial = Voter.where("id in (?)" ,voter_ids)
     
     begin
       EM.synchrony do
         concurrency = 10
         EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
           Twillio.dial_predictive_em(iter, voter)
         end
         EventMachine.stop
       end
       campaign.decrement_campaign_dial_count(voters_to_dial.size)
      rescue Exception => e
        EventMachine.stop
        puts e        
      end
   end
end
