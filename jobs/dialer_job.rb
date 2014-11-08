require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

##
# Proxy for +Dial.perform+.
# Queued from +CalculateDialsJob+.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure (WARNING: Dial.perform rescues all exceptions)
#
class DialerJob 
  @queue = :dialer_worker


   def self.perform(campaign_id, voter_ids)
     Dial.perform(campaign_id, voter_ids)
   end
end
