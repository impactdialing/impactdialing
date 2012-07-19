require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  include Sidekiq::Worker
  sidekiq_options :queue => :dialer_worker


   def perform(campaign_id, nums_to_call)
     campaign = Campaign.find(campaign_id)
     EM.synchrony do
       concurrency = 8
       voters_to_dial = campaign.choose_voters_to_dial(nums_to_call)
       EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
         voter.dial_predictive_em(iter)
       end
       campaign.update_attributes(calls_in_progress: false)
       EventMachine.stop
     end
   end
end