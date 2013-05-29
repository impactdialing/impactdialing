module Client
  class SessionsController < ClientController
    skip_before_filter :check_login, :only => :create

    def create
      user = User.authenticate(params[:email], params[:password])
      if user
        session[:user] = user.id
        flash_message(:kissmetrics, "Signed In")
        redirect_to '/client/index'
      else
        flash_now(:error, "The email or password you entered was incorrect. Please try again.")
        render 'client/sessions/new'
      end
    end

    def destroy
      session[:user] = nil
      flash_message(:notice, "You have been logged out.")
      redirect_to login_path
    end
  end
end
