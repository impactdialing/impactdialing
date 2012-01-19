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
        flash_message(:error, "#{params[:email]} has already been invited.")
      elsif User.find_by_email(params[:email])
        flash_message(:error, "#{params[:email]} is already part of a different account.")
      else
        random_password = rand(Time.now.to_i)
        new_user = account.users.create!(:email => params[:email], :new_password => random_password.to_s)
        new_user.create_reset_code!
        UserMailer.new.deliver_invitation(new_user, @user)
      end
      redirect_to :back
    end

    def destroy
      user_to_be_deleted = account.users.find_by_id(params[:id])
      if current_user == user_to_be_deleted
        flash_message(:error, "You can't delete yourself")
      else
        flash_message(:notice, "#{user_to_be_deleted.email} was deleted")
        user_to_be_deleted.destroy
      end
      redirect_to :back
    end
  end
end
