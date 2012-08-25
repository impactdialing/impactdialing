class MonitorsController < ClientController
  skip_before_filter :check_login, :only => [:start,:stop,:switch_mode, :deactivate_session]
  layout 'client'
  
  def index
    @campaigns = account.campaigns.manual.active
    @active_campaigns = account.campaigns.manual.active.with_running_caller_sessions
  end
  
  
  def show
    @all_campaigns = account.campaigns.manual.active
    @campaign = Campaign.find(params[:id])
    num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining = MonitorCampaign.campaign_overview_info(@campaign)
    MonitorCampaign.new(@campaign.id, num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining)    
    @monitor_session = MonitorSession.add_session(@campaign.id)
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
    Pusher[params[:monitor_session]].trigger('set_status',{:status_msg => status_msg})
    render xml:  caller_session.join_conference(params[:type]=="eaves_drop", params[:CallSid], params[:monitor_session])    
  end
    
  def kick_off
    caller_session = CallerSession.find(params[:session_id])
    caller_session.end_running_call
    render nothing: true
  end

  def switch_mode
    type = params[:type]
    caller_session = CallerSession.find(params[:session_id])
    MonitorCampaign.switch_monitor_mode(caller_session, type, params[:monitor_session])
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
    MonitorSession.remove_session(params[:campaign_id], params[:monitor_session])
    render nothing: true
  end
      
  def toggle_call_recording
    account.toggle_call_recording!
    flash_message(:notice, "Call recording turned #{account.record_calls? ? "on" : "off"}.")
    redirect_to monitors_path
  end
  

end
