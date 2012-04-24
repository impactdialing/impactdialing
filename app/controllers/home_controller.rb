class HomeController < ApplicationController
  def index
    if request.subdomains.first=="caller"
      redirect_to caller_root_path
    elsif request.subdomains.first=="broadcast"
      redirect_to broadcast_root_path
    else
      redirect_to client_root_path
    end
  end
  
  def tos
  end

  def policies
  end
end
