require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class Dial
  
  def self.perform(campaign_id, voter_ids)
    campaign = Campaign.find(campaign_id)     
    voters_to_dial = Voter.where("id in (?)" ,voter_ids)
    data_centres = RedisDataCentre.data_centres_array(campaign_id)
    dcs_hash = {}
    total = 0
    data_centres.each do |dc|
      on_hold = RedisOnHoldCaller.length(campaign_id, dc)
      dcs_hash[dc] = on_hold  
      total = total + on_hold
    end
    puts "Campaign: #{campaign_id}, Total: #{total}, #{dcs_hash.inspect}"
    start = 0
    dcs_hash.each_pair do |key, value|
      number_to_dial = (voters_to_dial.size.to_f / total.to_f) * value
      puts "Campaign: #{campaign_id}, Numbers to Dial: #{number_to_dial}"
      em_dial(voters_to_dial[start, number_to_dial], key)
      start = number_to_dial
    end
    
    
  end
  
  def self.em_dial(voters_to_dial, key)
    begin
      EM.synchrony do
        concurrency = 10        
        EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
          Twillio.dial_predictive_em(iter, voter, key)
        end        
        EventMachine.stop
      end
      
     rescue Exception => e
       puts e
     end    
  end
end