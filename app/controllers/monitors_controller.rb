class MonitorsController < ClientController
  skip_before_filter :check_login, :only => [:start, :stop, :switch_mode, :deactivate_session]
      respond_to :json, :html

  def index
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end


  def start
    caller_session = CallerSession.find(params[:session_id])
    if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
      status_msg = "Status: Monitoring in "+ params[:type] + " mode on "+ caller_session.caller.identity_name + "."
    else
      status_msg = "Status: Caller is not connected to a lead."
    end
    Pusher[params[:monitor_session]].trigger('set_status', {:status_msg => status_msg})
    render xml: caller_session.join_conference(params[:type]=="eaves_drop", params[:CallSid], params[:monitor_session])
  end

  def kick_off
    caller_session = CallerSession.find(params[:session_id])
    caller_session.end_running_call
    render nothing: true
  end

  def switch_mode
    type = params[:type]
    caller_session = CallerSession.find(params[:session_id])
    caller_session.moderator.switch_monitor_mode(caller_session, type)
    if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
      render text: "Status: Monitoring in "+ type + " mode on "+ caller_session.caller.identity_name + "."
    else
      render text: "Status: Caller is not connected to a lead."
    end
  end

  def stop
    caller_session = CallerSession.find(params[:session_id])
    caller_session.moderator.stop_monitoring(caller_session)
    render text: "Switching to different caller"
  end

  def deactivate_session
    moderator = Moderator.find_by_session(params[:monitor_session])
    moderator.update_attributes(:active => false) unless moderator.nil?
    render nothing: true
  end

  def monitor_session
    @moderator = Moderator.create!(:session => generate_session_key, :account => @user.account, :active => true)
    render json: @moderator.session.to_json
  end

  def toggle_call_recording
    account.toggle_call_recording!
    flash_message(:notice, "Call recording turned #{account.record_calls? ? "on" : "off"}.")
    redirect_to monitors_path
  end

end
