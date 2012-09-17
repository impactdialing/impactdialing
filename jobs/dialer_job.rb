require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id, voter_ids)
     Dial.perform(campaign_id, voter_ids)
   end
end
