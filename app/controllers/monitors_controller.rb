class MonitorsController < ClientController
  skip_before_filter :check_login, :only => [:start, :stop, :switch_mode, :deactivate_session]
      respond_to :json, :html

  def index
    authorize! :view_dashboard, @account
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
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
    @moderator = Moderator.create!(:session => generate_session_key, :account => account)
    render json: @moderator
  end

  def toggle_call_recording
    account.toggle_call_recording!
    flash_message(:notice, "Call recording turned #{account.record_calls? ? "on" : "off"}.")
    redirect_to monitors_path
  end

end
