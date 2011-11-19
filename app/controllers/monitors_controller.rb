class MonitorsController < ClientController
  layout 'v2'
  
  def index
    @campaigns = account.campaigns.with_running_caller_sessions
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end
  
  def start
    @call_sid = params[:CallSid]
    session = CallerSession.find(params[:session_id])    
    mute_type = params[:type]=="breakin" ? false : true
    render xml:  session.join_conference(mute_type)
  end
  
  def switch_mode
    session = CallerSession.find(params[:session_id])
    session.moderator.switch_monitor_mode(session)
    render nothing: true
  end
  
  def stop
    session = CallerSession.find(params[:session_id])
    session.moderator.stop_monitoring(session)
    render nothing: true
  end
  
end
