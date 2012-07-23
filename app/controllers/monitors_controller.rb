class MonitorsController < ClientController
  skip_before_filter :check_login, :only => [:start,:stop,:switch_mode, :deactivate_session]
  layout 'client'
  
  def index
    @campaigns = account.campaigns.with_running_caller_sessions
    @all_campaigns = account.campaigns.manual.active
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
  end
  
  def new_index
    @campaigns = account.campaigns.manual.active
    @active_campaigns = account.campaigns.manual.active.with_running_caller_sessions
    @inactive_campaigns = account.campaigns.manual.active.with_non_running_caller_sessions
  end
  
  
  def show
    @campaign = Campaign.find(params[:id])
    num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining = campaign_overview_info(@campaign)
    MonitorCampaign.new(@campaign.id, num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining)    
    @monitor_session = MonitorSession.add_session(@campaign.id)
    twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    twilio_capability.allow_client_outgoing(MONITOR_TWILIO_APP_SID)
    @token = twilio_capability.generate
    
  end
  
  def campaign_overview_info(campaign)
    num_logged_in = campaign.caller_sessions.on_call.size
    num_on_call = campaign.caller_sessions.not_available.size
    num_wrapup = campaign.call_attempts.not_wrapped_up.between(3.minutes.ago, Time.now).size
    num_on_hold = campaign.caller_sessions.available.size
    num_live_lines = campaign.call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::INPROGRESS).size
    num_ringing_lines = campaign.call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    num_remaining = campaign.all_voters.by_status('not called').count
    num_available = num_voter_available(campaign) + num_remaining
    [num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining]
  end
  
  def num_voter_available(campaign)
    voters_available_for_retry = campaign.all_voters.enabled.avialable_to_be_retried(campaign.recycle_rate).count
    scheduled_for_now = campaign.all_voters.scheduled.count
    abandoned_count = campaign.all_voters.by_status(CallAttempt::Status::ABANDONED).count
    sanitize_dials(voters_available_for_retry + scheduled_for_now + abandoned_count)
  end
  

  def start
    caller_session = CallerSession.find(params[:session_id])
    if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
      status_msg = "Status: Monitoring in "+ params[:type] + " mode on "+ caller_session.caller.identity_name + "."
    else
      status_msg = "Status: Caller is not connected to a lead."
    end
    Pusher[params[:monitor_session]].trigger('set_status',{:status_msg => status_msg})
    mute_type = params[:type]=="breakin" ? false : true
    render xml:  caller_session.join_conference(mute_type, params[:CallSid], params[:monitor_session])
  end
  
  def kick_off
    caller_session = CallerSession.find(params[:session_id])
    caller_session.end_running_call
    render nothing: true
  end

  def switch_mode
    type = params[:type]
    caller_session = CallerSession.find(params[:session_id])
    if caller_session.moderator.nil?
      render text: "Status: There is some problem in switching mode. Please refresh the page"
    else
      caller_session.moderator.switch_monitor_mode(caller_session, type)
      if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
        render text: "Status: Monitoring in "+ type + " mode on "+ caller_session.caller.identity_name + "."
      else
        render text: "Status: Caller is not connected to a lead."
      end 
    end
  end

  def stop
    caller_session = CallerSession.find(params[:session_id])
    caller_session.moderator.stop_monitoring(caller_session)
    render text: "Switching to different caller"
  end
  
  def deactivate_session(campaign_id, session_key)
    MonitorSession.remove_session(campaign_id, session_key)
    render nothing: true
  end
      
  def toggle_call_recording
    account.toggle_call_recording!
    flash_message(:notice, "Call recording turned #{account.record_calls? ? "on" : "off"}.")
    redirect_to monitors_path
  end
  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
  

end
