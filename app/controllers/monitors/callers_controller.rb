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
      type = params[:type]
      caller_session = CallerSession.find(params[:session_id])
      caller_session.moderator.switch_monitor_mode(caller_session, type)
      if caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
        respond_with({message: "Status: Monitoring in "+ type + " mode on "+ caller_session.caller.identity_name + "."})
      else
        respond_with({message: "Status: Caller is not connected to a lead."})
      end
    end


  end
end