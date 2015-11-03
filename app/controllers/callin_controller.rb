class CallinController < TwimlController
  include SidekiqEvents

  skip_before_filter :verify_authenticity_token
  before_filter :next_attempt # set @next & @current _attempt
  before_filter :authenticate_by_pin
  before_filter :verify_campaign_assigned

  if instrument_actions?
    instrument_action :identify, :create
  end

private
  def pin
    params[:Digits]
  end

  def current_attempt
    @current_attempt ||= (params[:attempt] || 0).to_i
  end

  def caller_record
    @caller_record ||= (Caller.find_by_pin(pin) or caller_identity.try(:caller))
  end

  def caller_identity
    @caller_identity ||= CallerIdentity.find_by_pin(pin)
  end

  def campaign
    caller_record.campaign
  end

  def session_key
    @session_key ||= (caller_identity.try(:session_key) or generate_session_key)
  end

  def matching_pin_found
    caller_identity or caller_record
  end

  def authenticate_by_pin
    unless pin.present? and matching_pin_found
      render_twiml 'caller_sessions', 'pin_prompt' and return
    end
  end

  def verify_campaign_assigned
    unless caller_record.campaign.present?
      render_twiml 'caller_sessions', 'campaign_missing' and return
    end
  end

  def next_attempt
    @next_attempt ||= current_attempt + 1
  end

public
  def create
  end

  def identify
    session         = caller_record.create_caller_session(session_key, params[:CallSid], CallerSession::CallerType::PHONE)
    @caller_session = CallerSession.find_by_id_cached(session.id)

    render_abort_twiml_unless_fit_to(:start_calling, @caller_session) do
      CallFlow::CallerSession.create(params)
      RedisPredictiveCampaign.add(campaign.id, caller_record.campaign.type)
      RedisStatus.set_state_changed_time(caller_record.campaign.id, "On hold", @caller_session.id)

      if caller_record.is_phones_only?
        CachePhonesOnlyScriptQuestions.add_to_queue caller_record.campaign.script_id, 'seed'
      else
        @caller_session.start_conf
      end

      render_twiml 'caller_sessions', 'identify' and return
    end
  end
end

