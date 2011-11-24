class MonitorsController < ClientController
  layout 'client'

  def index
    @campaigns = account.campaigns.with_running_caller_sessions
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end

  def start
    session = CallerSession.find(params[:session_id])
    unless session.voter_in_progress.call_attempts.last.status == "Call in progress"
      Pusher[params[:monitor_session]].trigger('no_voter_on_call',{})
    end
    mute_type = params[:type]=="breakin" ? false : true
    render xml:  session.join_conference(mute_type, params[:CallSid])
  end

  def switch_mode
    type = params[:type]
    session = CallerSession.find(params[:session_id])
    session.moderator.switch_monitor_mode(session, type)
    render text: "You're currently "+ type + " on "+ session.caller.name
  end

  def stop
    session = CallerSession.find(params[:session_id])
    session.moderator.stop_monitoring(session)
    render nothing: true
  end

end
