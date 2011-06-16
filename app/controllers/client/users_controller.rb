module Client
  class UsersController < ClientController
    INVALID_RESET_TOKEN = 'Your password reset link is invalid'
    skip_before_filter :check_login, :only => [:reset_password, :update_password]
    skip_before_filter :check_paid, :only => [:reset_password, :update_password]

    def reset_password
      @user = User.find_by_password_reset_code(params[:reset_code])
      unless @user
        flash_message(:error, INVALID_RESET_TOKEN)
        redirect_to root_path
      end

    end

    def update_password
      user = User.find(params[:user_id])
      if user.password_reset_code == params[:reset_code]
        user.new_password = params[:password]
        user.clear_reset_code
        user.save!
        flash_message(:notice, 'Your password has been successfully reset')
      else
        flash_message(:error, INVALID_RESET_TOKEN)
      end
      redirect_to root_path
    end
  end
end
