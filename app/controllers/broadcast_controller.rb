class BroadcastController < ClientController
  layout 'v2'

  def index
  end

  def redirect_to_login
    redirect_to broadcast_login_path
  end

end
