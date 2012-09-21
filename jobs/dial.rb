require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class Dial
  
  def self.perform(campaign_id, voter_ids)
    campaign = Campaign.find(campaign_id)     
    voters_to_dial = Voter.where("id in (?)" ,voter_ids)
    begin
      EM.synchrony do
        concurrency = 10        
        EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
          voter.dial_predictive_em(iter)
        end        
        EventMachine.stop
      end
      
     rescue Exception => e
       puts e
     end
    
  end
end