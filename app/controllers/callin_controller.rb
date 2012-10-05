class CallinController < ApplicationController
  include SidekiqEvents
  skip_before_filter :verify_authenticity_token

  def create
    render :xml => Caller.ask_for_pin
  end

  def identify
    identity = CallerIdentity.find_by_pin(params[:Digits])
    caller = identity.nil? ?  Caller.find_by_pin(params[:Digits]) : identity.caller
    session_key = identity.nil? ? generate_session_key : identity.session_key
    if caller
      session = caller.create_caller_session(session_key, params[:CallSid], CallerSession::CallerType::PHONE)
      caller.started_calling(session)
      render xml:  caller.is_phones_only? ? session.run('callin_choice') : session.run('start_conf')
    else
      render xml:  Caller.ask_for_pin(params[:attempt].to_i)
    end
  end
end
