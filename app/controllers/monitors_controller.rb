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
  
  def poll_for_updates
    moderator = Moderator.find_by_session(params[:monitor_session]) 
    moderator.account.campaigns.each do |campaign|
      caller_sessions = CallerSession.on_call.on_campaign(campaign)
      caller_sessions.each do |caller_session|
        EM.run {
          voter_event_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})
          update_dials_in_progress_deferrable = Pusher[moderator.session].trigger_async('update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
          
          voter_event_deferrable.callback {}
          update_dials_in_progress_deferrable.callback{}
            
          voter_event_deferrable.errback {|error|}
          update_dials_in_progress_deferrable.errback {|errback|}
        }        
      end
    end          
    render nothing: true
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
