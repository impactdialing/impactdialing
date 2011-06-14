module Client
  class UsersController < ClientController
    skip_before_filter :check_login, :only => [:reset_password, :update_password]
    skip_before_filter :check_paid, :only => [:reset_password, :update_password]

    def reset_password
      @user = User.find_by_password_reset_code(params[:reset_code])
    end

    def update_password
      user = User.find(params[:user_id])
      if user.password_reset_code == params[:reset_code] && params[:password] == params[:confirm_password]
        user.new_password = params[:password]
        user.clear_reset_code
        user.save!
        flash[:notice] == 'Your password has been successfully reset'
      end
      redirect_to root_path
    end
  end
end
