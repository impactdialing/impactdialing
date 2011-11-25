class MonitorsController < ClientController
  layout 'client'
  
  def index
    @campaigns = account.campaigns.with_running_caller_sessions
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end

  def start
    caller_session = CallerSession.find(params[:session_id])
    if caller_session.voter_in_progress
      unless caller_session.voter_in_progress.call_attempts.last.status != "Call in progress."
        Pusher[params[:monitor_session]].trigger('no_voter_on_call',{})
      end
    end
    mute_type = params[:type]=="breakin" ? false : true
    render xml:  caller_session.join_conference(mute_type, params[:CallSid], params[:monitor_session])
  end

  def switch_mode
    type = params[:type]
    caller_session = CallerSession.find(params[:session_id])
    caller_session.moderator.switch_monitor_mode(caller_session, type)
    render text: "Monitoring in "+ type + " mode on "+ caller_session.caller.email + "."
  end

  def stop
    moderator = Moderator.find_by_session(params[:monitor_session])
    moderator.update_attributes(:active => false)
    # caller_session = CallerSession.find(params[:session_id])
    # caller_session.moderator.stop_monitoring(session)
    render nothing: true
  end
  
  def monitor_session
    puts session
    @moderator = Moderator.create!(:session => generate_session_key, :account => @user.account, :active => true)
    render json: @moderator.session.to_json
  end

end
