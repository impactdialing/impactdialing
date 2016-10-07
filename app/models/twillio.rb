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
      def self.key(campaign)
        new(campaign).send(:base_key)
      end

      def initialize(campaign)
        @campaign = campaign
      end

      def incby(status, n)
        redis.hincrby base_key, status, n
      end

      def inc(status)
        incby(status, 1)
      end

      def dec(status)
        incby(status, -1)
      end

      def get(status)
        (redis.hget(base_key, status) || 0).to_i
      end

      def set(status, value)
        redis.hset(base_key, status, value)
      end

      def update_last_dial_time
        set('last_dial_time', Time.now.utc.to_i)
      end

      def last_dial_time
        get('last_dial_time')
      end

      def delete
        redis.del base_key
      end
  end

  def self.error_response_codes
    # 401: unauthorized
    # 405: method not allowed
    # 429: too many requests
    # 666: there be dragons: JSON::ParserError: A JSON text must at least contain two octets!
    #                        Began appearing before rails 4 upgrade approx Mar 19 2015.
    [400, 401, 404, 405, 429, 500, 666]
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
  end

  def self.count_dial_error(campaign, caller_session=nil)
    ImpactPlatform::Metrics.count('dialer.dial.error', '1', count_source(campaign, caller_session))
  end
  
  def self.handle_response(http_response, campaign, phone, caller_session=nil)
    campaign.update_last_dial_time

    response = if http_response.blank?
                 {
                  'status' => 666,
                  'RestException' => [
                    'Invalid JSON response returned from REST request',
                    'to Twilio for new call.',
                    "Campaign[#{campaign.id}]",
                    "Phone[#{phone}]"
                  ].join(' ')
                }
               else
                 JSON.parse(http_response)
               end
    if error_response_codes.include?(response["status"])
      handle_failed_call(phone, campaign, caller_session, response)
    else
      handle_succeeded_call(phone, campaign, caller_session, response)
    end
  end

  def self.dial(phone, caller_session)
    campaign      = caller_session.campaign
    twilio_lib    = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http_response = twilio_lib.make_call(campaign, phone)
    handle_response(http_response, campaign, phone, caller_session)
  end

  def self.dial_predictive_em(iter, campaign, phone)
    twilio_lib   = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    http         = twilio_lib.make_call_em(campaign, phone)
    handle_response(http.response, campaign, phone)
  end

  def self.mark_caller_unavailable(caller_session)
    return if caller_session.nil? # the case when call first made in predictive mode
                                  # if predictive call is picked up, then this is called
                                  # again w/ caller_session present from /incoming end-point

    caller_session.update_attributes({
      on_call: true,
      available_for_call: false
    })
  end

  def self.predictive_dial_answered(caller_session, params)
    mark_caller_unavailable(caller_session) if caller_session.on_call? # caller may have disconnected
    dialed_call                    = CallFlow::Call::Dialed.new(params[:AccountSid], params[:CallSid])
    dialed_call.caller_session_sid = caller_session.sid
  end

  def self.create_dialed_call(campaign, response, phone, caller_session=nil)
    optional_properties = {
      phone: phone,
      campaign_id: campaign.id
    }
    if caller_session.present?
      optional_properties[:caller_session_sid] = caller_session.sid
    end

    CallFlow::Call::Dialed.create(campaign, response, optional_properties)
  end

  def self.handle_succeeded_call(phone, campaign, caller_session, response)
    count_dial_success(campaign, caller_session)
    create_dialed_call(campaign, response, phone, caller_session)
    mark_caller_unavailable(caller_session)

    response
  end

  def self.handle_failed_call(phone, campaign, caller_session, response)
    TwilioLogger.error(response['TwilioResponse'] || response)
    count_dial_error(campaign, caller_session)

    CallFlow::Call::Failed.create(campaign, phone, response['TwilioResponse'] || response, campaign.predictive?)

    unless caller_session.nil?
      Providers::Phone::Call.redirect_for(caller_session)
    end
    response
  end
end

