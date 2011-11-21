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
    mute_type = params[:type]=="breakin" ? false : true
    render xml:  session.join_conference(mute_type, params[:CallSid])
  end
  
  def switch_mode
    type = params[:type]
    session = CallerSession.find(params[:session_id])
    session.moderator.switch_monitor_mode(session, type)
    render nothing: true
  end
  
  def stop
    session = CallerSession.find(params[:session_id])
    session.moderator.stop_monitoring(session)
    render nothing: true
  end
  
end
