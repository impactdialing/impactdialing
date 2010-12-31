class HomeController < ApplicationController
  def index
    if request.subdomains.first=="caller"
      redirect_to :controller=>"caller"
    else
      #redirect_to :controller=>"client"
    end
    @user = User.new
    render :layout=>false
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
    render :layout=>"client"
  end

  def monitor
    render :text=>"OK"
    return
  end
end
