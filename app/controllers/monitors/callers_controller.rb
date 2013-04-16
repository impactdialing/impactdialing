module Monitors
  class CallersController < ClientController
    skip_before_filter :check_login, :only => [:kick_off]
    skip_before_filter :verify_authenticity_token, :only => [:start]
    respond_to :json

    def index
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @campaigns = Account.find(account).campaigns.with_running_caller_sessions
        @callers = @campaigns.collect{|c| c.current_callers_status}
      end
      respond_with(@callers.flatten)
    end

    def kick_off
      caller_session = CallerSession.find(params[:session_id])
      caller_session.end_running_call
      respond_with(caller_session)
    end

    def switch_mode
      caller_session = CallerSession.find(params[:session_id])
      moderator = Moderator.find(params["monitor_session_id"])
      moderator.update_attributes(caller_session_id: caller_session.id)
      caller_session.moderator.switch_monitor_mode(params[:type])
      if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
        render text: "Status: Monitoring in "+ type + " mode on "+ caller_session.caller.identity_name + "."
      else
        render text: "Status: Caller is not connected to a lead."
      end
    end

    def start
      caller_session = CallerSession.find(params[:session_id])
      moderator = Moderator.find(params["monitor_session_id"])
      moderator.update_attributes(caller_session_id: caller_session.id, call_sid: params['CallSid'])
      if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
        status_msg = "Status: Monitoring in "+ params[:type] + " mode on "+ caller_session.caller.identity_name + "."
      else
        status_msg = "Status: Caller is not connected to a lead."
      end
      render xml: caller_session.join_conference(params[:type]=="eaves_drop")
    end

    def reassignable_campaigns
      @campaigns = account.campaigns.manual.active.select {|x| !x.time_period_exceeded?}
      respond_with(@campaigns.collect{|c| {id: c.id, name: c.name}})
    end

    def reassign_campaign
      caller_session = CallerSession.find(params[:caller_session_id])
      caller_sesion.update_attribute(:campaign_id, params[:campaign_id])
    end


  end
end