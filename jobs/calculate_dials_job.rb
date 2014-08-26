require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'resque-loner'


class CalculateDialsJob
  include Resque::Plugins::UniqueJob

  @queue = :dialer_worker


  def self.perform(campaign_id)
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    begin
      campaign = Campaign.find(campaign_id)
      num_to_call = campaign.number_of_voters_to_dial - campaign.dialing_count
      
      Rails.logger.info "Campaign: #{campaign.id} - num_to_call #{num_to_call}"

      if num_to_call <= 0
        Resque.redis.del("dial_calculate:#{campaign.id}")
        return
      end
      voters_to_dial = campaign.choose_voters_to_dial(num_to_call)
      Resque.enqueue(DialerJob, campaign.id, voters_to_dial)
    rescue Exception => e
      metrics.error
      Rails.logger.error("#{self} Exception: #{e.class}: #{e.message}")
      Rails.logger.error("#{self} Exception Backtrace: #{e.backtrace}")
    ensure
      Resque.redis.del("dial_calculate:#{campaign.id}")
    end

    metrics.completed
  end
end
