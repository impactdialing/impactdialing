require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'resque-loner'

##
# Determine number of +Voter+ records that should be dialed, if any and queue +DialerJob+.
# Does nothing if the number of +Voter+ records that should be dialed is zero.
# Queues +CampaignOutOfNumbersJob+ when the number of +Voter+ records that should be dialed is > 0
# but there are not +Voter+ records left in the dial queue.
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
  extend SidekiqEvents::InstanceMethods

  @queue = :dialer_worker


  def self.perform(campaign_id)
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    begin
      campaign = Campaign.find(campaign_id)

      unless campaign.check_campaign_fit_to_dial
        stop_calculating(campaign_id)
        metrics.completed
        return
      end

      # here is potential for predictive dialing to slow down erroneously.
      # given some voters w/ status of READY that haven't actually been dialed
      # and some number of voters to dial
      # the actual dialed amount is reduced by the stale READY voters
      num_to_call = campaign.number_of_voters_to_dial - campaign.dialing_count
      
      # todo: track predictive calculated number of voters to call in librato compatible way
      Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"

      if num_to_call <= 0
        stop_calculating(campaign_id)
        metrics.completed
        return
      end

      voters_to_dial = campaign.choose_voters_to_dial(num_to_call)
      unless voters_to_dial.empty?
        Resque.enqueue(DialerJob, campaign_id, voters_to_dial)
      else
        campaign.caller_sessions.available.pluck(:id).each do |id|
          enqueue_call_flow(CampaignOutOfNumbersJob, [id])
        end
      end
    rescue Resque::TermException => e
      metrics.sigterm
      raise e

    ensure
      stop_calculating(campaign_id)
    end

    metrics.completed
  end

  def self.stop_calculating(campaign_id)
    Resque.redis.del("dial_calculate:#{campaign_id}")
  end
end
