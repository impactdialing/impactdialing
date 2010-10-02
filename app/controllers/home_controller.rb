class HomeController < ApplicationController
  def index
    @user = User.new
  #  redirect_to :controller=>"client"
  end
  
  def how_were_different
    
  end
  
  def pricing
    
  end

  def contact
    
  end
  
  def tos
    render :layout=>"client"
  end

  def monitor
    render :text=>"OK"
    return
  end
end
