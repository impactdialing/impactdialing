class MonitorController < ClientController
  layout 'v2'
  def index
    @campaigns = @user.campaigns.with_running_caller_sessions
  end
end