require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

##
# Workhorse for +DialerJob.perform+.
#
# todo: stop rescuing everything.
#
class Dial
  def self.perform(campaign_id, voter_ids)
    campaign       = Campaign.find(campaign_id)     
    voters_to_dial = Voter.where("id in (?)" ,voter_ids)
    
    puts "Campaign: #{campaign_id}, Numbers to Dial: #{voter_ids.size}"
    
    em_dial(voters_to_dial)
  end
  
  def self.em_dial(voters_to_dial, key='twilio')
    begin
      EM.synchrony do
        concurrency = 10        
        EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
          Twillio.dial_predictive_em(iter, voter, key)
        end        
        EventMachine.stop
      end
      
     rescue => e
       Rails.logger.error "#{e.class} #{e.message}"
     end    
  end
end