require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require "em-synchrony/fiber_iterator"

##
# Workhorse for +DialerJob.perform+.
#
# todo: stop rescuing everything.
#
class Dial
  def self.perform(campaign_id, phone_numbers)
    campaign   = Campaign.find(campaign_id)
    em_dial(campaign, phone_numbers)
  end

  def self.em_dial(campaign, phone_numbers)
    EM.synchrony do
      concurrency = 10
      EM::Synchrony::FiberIterator.new(phone_numbers, concurrency).each do |phone, iter|
        Twillio.dial_predictive_em(iter, campaign, phone)
      end
      EventMachine.stop
    end
  end
end
