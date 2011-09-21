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

    def invite
      if account.users.find_by_email(params[:email])
        flash[:error] = "#{params[:email]} has already been invited."
      elsif User.find_by_email(params[:email])
        flash[:error] = "#{params[:email]} is already part of a different account."
      else
        random_password = rand(Time.now)
        new_user = account.users.create!(:email => params[:email], :new_password => random_password.to_s)
        new_user.create_reset_code
        UserMailer.new.deliver_invitation(new_user, @user)
        redirect_to :back
      end
    end
  end
end
