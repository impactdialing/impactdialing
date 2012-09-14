require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id, voter_ids)
     voters_to_dial = Voter.where("id in (?)" voter_ids)
     begin
       EM.synchrony do
         concurrency = 10
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
