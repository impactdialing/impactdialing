class CallinController < TwimlController
  include SidekiqEvents

  skip_before_filter :verify_authenticity_token
private
  def ask_for_pin_twiml
    attempt = params[:attempt].to_i
    xml     = Twilio::Verb.new do |twiml|
      if attempt > 0
        twiml.say 'Incorrect pin.'
      end

      if attempt > 2
        twiml.hangup
      else
        twiml.gather({
          finishOnKey: '*',
          timeout:     10,
          method:      'POST',
          action:      identify_caller_url({
            host:     Settings.twilio_callback_host,
            port:     Settings.twilio_callback_port,
            protocol: 'http://',
            attempt:  attempt + 1
          })
        }) do
          twiml.say 'Please enter your pin and then press star.'
        end
      end
    end
    xml.response
  end

public
  def create
    render :xml => ask_for_pin_twiml
  end

  def identify
    identity = CallerIdentity.find_by_pin(params[:Digits])
    caller = identity.nil? ?  Caller.find_by_pin(params[:Digits]) : identity.caller
    session_key = identity.nil? ? generate_session_key : identity.session_key
    if caller
      session = caller.create_caller_session(session_key, params[:CallSid], CallerSession::CallerType::PHONE)
      load_caller_session = CallerSession.find_by_id_cached(session.id)

      render_abort_twiml_unless_fit_to(:start_calling, load_caller_session) do

        caller.started_calling(load_caller_session)

        if caller.is_phones_only?
          CachePhonesOnlyScriptQuestions.add_to_queue caller.campaign.script_id, 'seed'
          xml = load_caller_session.callin_choice
        else
          RedisDataCentre.set_datacentres_used(load_caller_session.campaign_id, DataCentre.code(params[:caller_dc]))
          load_caller_session.start_conf
          xml = load_caller_session.connected_twiml
        end

        render xml: xml and return
      end
    else
      render xml: ask_for_pin_twiml and return
    end
  end
end

