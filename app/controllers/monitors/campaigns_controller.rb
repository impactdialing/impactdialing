module Monitors
  class CampaignsController < ClientController
    skip_before_filter :check_login, :only => []
    respond_to :json

    if instrument_actions?
      instrument_action :index
    end

    def index
      authorize! :view_dashboard, @account
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @campaigns = account.campaigns.active.with_running_caller_sessions
      end
      @campaigns = @campaigns.collect{|c| {name: c.name, id: c.id}.merge(c.current_status)}
      respond_with(@campaigns)
    end
  end
end
