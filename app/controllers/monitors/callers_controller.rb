module Monitors
  class CallersController < ClientController
    skip_before_filter :check_login, :only => [:kick_off]
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
      if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
        status_msg = "Status: Monitoring in "+ params[:type] + " mode on "+ caller_session.caller.identity_name + "."
      else
        status_msg = "Status: Caller is not connected to a lead."
      end
      Pusher[params[:monitor_session]].trigger('set_status', {:status_msg => status_msg})
    render xml: caller_session.join_conference(params[:type]=="eaves_drop", params[:CallSid], params[:monitor_session])
    end


  end
end