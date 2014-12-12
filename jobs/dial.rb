require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

##
# Workhorse for +DialerJob.perform+.
#
# todo: stop rescuing everything.
#
class Dial
  def self.perform(campaign_id, phone_numbers)
    campaign   = Campaign.find(campaign_id)     
    households = campaign.households.where(phone: phone_numbers)
    
    em_dial(households)
  end
  
  def self.em_dial(households, key='twilio')
    EM.synchrony do
      concurrency = 10        
      EM::Synchrony::Iterator.new(households, concurrency).map do |household, iter|
        Twillio.dial_predictive_em(iter, household, key)
      end        
      EventMachine.stop
    end
  end
end