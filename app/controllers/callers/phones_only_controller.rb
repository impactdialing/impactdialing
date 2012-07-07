module Callers
  class PhonesOnlyController < ApplicationController
    before_filter :check_login, :only=> [:report]
    layout "client"
    
    def check_login
       redirect_to_login and return if session[:phones_only_caller].blank?
       begin
         @caller = Caller.find(session[:phones_only_caller])
         @account = @caller.account
       rescue
         logout
       end
     end
  
    def index
    end
    
    def login
      pin = params[:pin]
      password = params[:password]
      if pin.blank? || password.blank?
        flash_message(:error, "The pin or password you entered was incorrect. Please try again.")
        redirect_to :back
        return
      end
      caller = Account.authenticate_caller?(pin,password)
      unless caller.nil?
        session[:phones_only_caller] = caller.id
        redirect_to :action=>"report"
      else
        flash_message(:error, "The pin or password you entered was incorrect. Please try again.")
        redirect_to :action =>"index"
        return        
      end
        
    end
    
    def report      
      
    end
  end
end  