class MonitorController < ClientController
  layout 'v2'
  def index
    @campaigns = account.campaigns.with_running_caller_sessions
  end
end
