module Monitors
  class CallersController < ClientController
    skip_before_filter :check_login, :only => [:kick_off, :start]
    skip_before_filter :check_login, :only => [:kick_off, :start]
    skip_before_filter :check_tos_accepted, :only => [:kick_off, :start, :switch_mode, :reassignable_campaigns, :reassign_campaign]
    respond_to :json

    def index
      authorize! :view_dashboard, @account
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
      msg = ModeratedSession.switch_mode(moderator, caller_session, params[:type])
      render text: msg
    end

    def start
      caller_session = CallerSession.find(params[:session_id])
      moderator = Moderator.find(params["monitor_session_id"])
      moderator.update_attributes(caller_session_id: caller_session.id, call_sid: params['CallSid'])
      if caller_session.attempt_in_progress && (caller_session.attempt_in_progress.status == "Call in progress")
        status_msg = "Status: Monitoring in "+ params[:type] + " mode on "+ caller_session.caller.identity_name + "."
      else
        status_msg = "Status: Caller is not connected to a lead."
      end
      render xml: caller_session.join_conference(params[:type]=="eaves_drop")
    end

    def reassignable_campaigns
      if account.nil?
        @campaigns = []
      else
        @campaigns = account.campaigns.manual.active.select {|x| !x.time_period_exceeded?}
      end
      respond_with(@campaigns.collect{|c| {id: c.id, name: c.name}})
    end

    def reassign_campaign
      caller_session = CallerSession.find(params[:caller_session_id])
      caller_sesion.update_attribute(:campaign_id, params[:campaign_id])
    end


  end
end