class Twiml::CallerSessionsController < TwimlController
  def dialing_prohibited
    caller_session = CallerSession.find params[:caller_session_id]
    caller_session.end_caller_session
    @reason = caller_session.abort_dial_reason
  end

  def create
    # from CallerController#start_calling
    @caller        = Caller.includes(:campaign).find(params[:caller_id])
    campaign       = @caller.campaign
    identity       = CallerIdentity.find_by_session_key(params[:session_key])
    @caller_session = @caller.create_caller_session(identity.session_key, params[:CallSid], CallerSession::CallerType::TWILIO_CLIENT)

    CallFlow::CallerSession.create(params)
    RedisPredictiveCampaign.add(campaign.id, campaign.type)
    RedisStatus.set_state_changed_time(campaign.id, "On hold", @caller_session.id)

    # from CallerSession#start_conference
    @caller_session.start_conf
  end
end

