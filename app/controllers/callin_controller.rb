class CallinController < ApplicationController
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
      redis_connection = RedisConnection.call_flow_connection
      RedisCampaign.add_running_campaign(caller.campaign.id, caller.campaign.type, redis_connection)
      Moderator.caller_connected_to_campaign(caller, caller.campaign, session)
      render xml:  caller.is_phones_only? ? session.run('callin_choice') : session.run('start_conf')
    else
      render xml:  Caller.ask_for_pin(params[:attempt].to_i)
    end
  end
  
  def hold
    render :xml => Caller.hold
  end

end
