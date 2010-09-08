class HomeController < ApplicationController
  def index
    redirect_to :controller=>"client"
  end
  
  def tos
    render :layout=>"client"
  end

  def monitor
    render :text=>"OK"
    return
  end
end
