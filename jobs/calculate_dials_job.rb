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

  @loner_ttl = 150
  @queue = :dialer_worker

  def self.redis
    Resque.redis
  end

  def self.calculation_key(campaign_id)
    "dial_calculate:#{campaign_id}"
  end

  def self.add_to_queue(campaign_id)
    throw ArgumentError, "Invalid campaign_id" if campaign_id.blank?

    unless calculation_in_progress?(campaign_id)
      start_calculating(campaign_id)
      Resque.enqueue(CalculateDialsJob, campaign_id)
    end
  end

  def self.start_calculating(campaign_id)
    redis.set(calculation_key(campaign_id), true)
    redis.expire(calculation_key(campaign_id), 8)
  end

  def self.stop_calculating(campaign_id)
    redis.del(calculation_key(campaign_id))
  end

  def self.calculation_in_progress?(campaign_id)
    redis.exists(calculation_key(campaign_id))
  end

  def self.perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    unless fit_to_dial?(campaign)
      stop_calculating(campaign_id)
      return
    end

    # This could raise CallFlow::DialQueue::EmptyHousehold
    # which means all phone numbers next in queue have no voter data
    # for display. Let it raise & cause job failure; job is run every few seconds
    # and allowing it to fail will maintain failure record.
    phone_numbers = campaign.numbers_to_dial

    unless phone_numbers.empty?
      Resque.enqueue(DialerJob, campaign_id, phone_numbers)
    else
      out_of_numbers(campaign)
    end

    stop_calculating(campaign_id)
  end

  def self.out_of_numbers(campaign)
    return unless campaign.dial_queue.available.size.zero?

    campaign.caller_sessions.on_call.pluck(:id).each do |id|
      Sidekiq::Client.push({
        'queue' => 'call_flow',
        'class' => CampaignOutOfNumbersJob,
        'args' => [id]
      })
    end
  end

  def self.fit_to_dial?(campaign)
    unless campaign.fit_to_dial?
      campaign.abort_available_callers_with(:dialing_prohibited)
      return false
    end

    return campaign.any_numbers_to_dial?
  end
end
