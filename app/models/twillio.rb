class Twillio
  include SidekiqEvents

  class InflightStats
    attr_reader :campaign

    private
      def redis
        @redis ||= Redis.new
      end
      def base_key
        "inflight_stats:#{campaign.id}"
      end
    public
      def initialize(campaign)
        @campaign = campaign
      end

      def inc(status)
        redis.hincrby base_key, status, 1
      end

      def dec(status)
        redis.hincrby base_key, status, -1
      end

      def get(status)
        redis.hget(base_key, status) || 0
      end
  end

  def self.error_response_codes
    # 401: unauthorized
    # 405: method not allowed
    # 429: too many requests
    [400, 401, 404, 405, 429, 500]
  end

  def self.count_source(campaign, caller_session=nil)
    n = []
    n << campaign.type.to_s.downcase
    n << "ac-#{campaign.account_id}"
    n << "ca-#{campaign.id}"
    n << "cs-#{caller_session.id}" if caller_session.present?
    n.join('.')
  end

  def self.count_dial_success(campaign, caller_session=nil)
    ImpactPlatform::Metrics.count('dialer.dial.success', '1', count_source(campaign, caller_session))

    InflightStats.new(campaign).inc('ringing')
  end

  def self.count_dial_error(campaign, caller_session=nil)
    ImpactPlatform::Metrics.count('dialer.dial.error', '1', count_source(campaign, caller_session))
  end
  
  def self.handle_response(http_response, household, call_attempt, caller_session=nil)
    response = JSON.parse(http_response)
    if error_response_codes.include?(response["status"])
      handle_failed_call(call_attempt, caller_session, household, response)
    else
      handle_succeeded_call(call_attempt, caller_session, response)
    end
  end

  def self.dial(household, caller_session)
    campaign      = caller_session.campaign
    call_attempt  = setup_call(household, caller_session, campaign)
    twilio_lib    = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http_response = twilio_lib.make_call(campaign, household, call_attempt)
    handle_response(http_response, household, call_attempt, caller_session)
  end

  def self.dial_predictive_em(iter, household)
    call_attempt = setup_call_predictive(household, campaign, dc)
    twilio_lib   = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http         = twilio_lib.make_call_em(campaign, household, call_attempt, dc)
    http.callback {
      handle_response(http.response, household, call_attempt)
      iter.return(http)
    }
    http.errback { iter.return(http) }
  end

  def self.create_call_attempt(household, campaign, caller_session=nil)
    attempt_attrs = {
      campaign: campaign,
      dialer_mode: campaign.type,
      status: CallAttempt::Status::RINGING,
      call_start: Time.now
    }
    if caller_session.present?
      attempt_attrs.merge!({
        caller_session: caller_session,
        caller: caller_session.caller
      })
    end

    call_attempt = household.call_attempts.create(attempt_attrs)
    call         = Call.create(call_attempt: call_attempt, state: "initial")

    call_attempt
  end

  def self.setup_call_predictive(household, campaign)
    create_call_attempt(household, campaign)
  end

  def self.setup_call(household, caller_session, campaign)
    call_attempt = create_call_attempt(household, campaign, caller_session)
    caller_session.update_attributes({
      on_call: true,
      available_for_call: false,
      attempt_in_progress: call_attempt
    })
    call_attempt
  end

  def self.handle_succeeded_call(call_attempt, caller_session, response)
    count_dial_success(call_attempt.campaign, caller_session)
    call_attempt.update_attributes(:sid => response["sid"])
  end

  def self.handle_failed_call(call_attempt, caller_session, household, response)
    TwilioLogger.error(response['TwilioResponse'] || response)
    count_dial_error(attempt.campaign, caller_session)

    call_attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)

    household.failed!
    
    unless caller_session.nil?
      caller_session.update_attributes(attempt_in_progress: nil, on_call: true, available_for_call: true)
      Providers::Phone::Call.redirect_for(caller_session)
    end
  end
end
