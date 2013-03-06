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

  end
end