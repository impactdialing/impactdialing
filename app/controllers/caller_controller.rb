class CallerController < ApplicationController
  layout "caller"
  before_filter :check_login, :except=>[:login]
  
  def index
    
  end


  def check_login
    if session[:caller].blank?
      redirect_to :action=>"login"
      return
    end
    begin
      @caller = Caller.find(session[:caller])
    rescue
      logout
    end
  end

  def login
    @breadcrumb="Login"
    @title="Login to Impact Dialing"

    if !params[:email].blank?
      @caller = Caller.find_by_email_and_password(params[:email],params[:password])
      if @caller.blank?
        flash.now[:error]="Invalid Login"
      else
        session[:caller]=@caller.id
        redirect_to :action=>"index"
      end
    end

  end

end
