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
    
    #Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    #Twilio.conference.mute_par
    session = CallerSession.find(params[:session_id])    
    if params[:type]=="breakin"
      mute_type = false
    else
      mute_type = true
    end
    render :xml => session.join_conference(mute_type)
  end
  
  def switch_mode
  end
end
