class CallinController < TwimlController
  include SidekiqEvents

  skip_before_filter :verify_authenticity_token

  def create
    render :xml => Caller.ask_for_pin(params[:provider])
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
          xml = load_caller_session.start_conf
        end

        render xml: xml and return
      end
    else
      render xml:  Caller.ask_for_pin(params[:attempt].to_i, params[:provider]) and return
    end
  end
end
