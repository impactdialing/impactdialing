class BroadcastController < ClientController

  def index
  end

  def redirect_to_login
    redirect_to broadcast_login_path
  end

  def policies
  end
end
