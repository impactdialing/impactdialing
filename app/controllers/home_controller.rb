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

  def homecss
    render :layout=>false, :content_type => "text/css"
  end

  def how_were_different

  end

  def pricing

  end

  def contact

  end

  def tos
  end

  def monitor
    render :text=>"OK"
    return
  end

  def policies
  end
end
