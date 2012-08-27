require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id, nums_to_call)
     campaign = Campaign.find(campaign_id)
     begin
       EM.synchrony do
         concurrency = 8
         voters_to_dial = campaign.choose_voters_to_dial(nums_to_call)
         EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
           Twillio.dial_predictive_em(iter, voter)
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
