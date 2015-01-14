require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'resque-loner'
require 'librato_resque'

##
# Determine number of phone numbers to dial, if any and queue +DialerJob+.
# Does nothing if the count of numbers to dial is zero.
# Queues +CampaignOutOfNumbersJob+ when the count of numbers to dial is > 0
# but there are no numbers in the dial queue.
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
# - 1 failure
#
class CalculateDialsJob
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :dialer_worker

  def self.perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    unless fit_to_dial?(campaign)
      stop_calculating(campaign_id)
      return
    end

    # This could raise CallFlow::DialQueue::Available::RedisTransactionAborted
    # which means the key containing the list of numbers changed while pullling numbers
    # off the queue. Let it bubble up & log as failed job since this is queued from
    # a loop (dialer_loop).
    phone_numbers = campaign.numbers_to_dial

    unless phone_numbers.empty?
      Resque.enqueue(DialerJob, campaign_id, phone_numbers)
    else
      campaign.caller_sessions.available.pluck(:id).each do |id|
        Sidekiq::Client.push('queue' => 'call_flow', 'class' => CampaignOutOfNumbersJob, 'args' => [id])
      end
    end

    stop_calculating(campaign_id)
  end

  def self.stop_calculating(campaign_id)
    Resque.redis.del("dial_calculate:#{campaign_id}")
  end

  def self.fit_to_dial?(campaign)
    unless campaign.fit_to_dial?
      campaign.abort_available_callers_with(:dialing_prohibited)
      return false
    end

    return campaign.any_numbers_to_dial?
  end
end
