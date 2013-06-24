module Client
  class UsersController < ClientController
    INVALID_RESET_TOKEN = 'Your link has expired or is invalid'
    skip_before_filter :check_login, :only => [:create, :reset_password, :update_password]
    skip_before_filter :check_paid, :only => [:reset_password, :update_password]
    before_filter :check_tos_accepted, :except => [:create, :reset_password, :update_password]

    def create
      @user = User.new(:account => Account.new(:domain_name => request.domain), role: User::Role::ADMINISTRATOR)
      @user.attributes = params[:user]
      if @user.save
        @user.create_recurly_account_code
        if ["aws", "heroku"].include?(ENV['RAILS_ENV'])
          user_mailer = UserMailer.new
          user_mailer.notify_new_signup(@user)
        end
        session[:user] = @user.id
        flash_message(:kissmetrics, "Signed Up")
        redirect_to '/client/tos'
      else
        render '/client/login'
      end
    end

    def update
      @user = current_user
      if @user.update_attributes(params[:user])
        flash_message(:notice, "Your information has been updated.")
        redirect_to '/client/account'
      else
        render '/client/users/edit'
      end
    end

    def reset_password
      @user = User.find_by_password_reset_code(params[:reset_code])
      unless @user
        flash_message(:error, INVALID_RESET_TOKEN)
        redirect_to login_path
      end
    end

    def update_password
      @user = User.find(params[:user_id])
      if @user.password_reset_code == params[:reset_code]
        @user.new_password = params[:password]
        @user.clear_reset_code
        if @user.save
          session[:user]=@user.id
          flash_message(:notice, 'Your password has been successfully set')
        else
          flash_message(:notice, 'Your password needs to be 5 characters or greater.')
        end
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
        new_user = account.users.create!(:email => params[:email], :new_password => random_password.to_s, role: params[:user][:role])
        new_user.create_reset_code!
        Resque.enqueue(DeliverInvitationEmailJob, new_user.id, current_user.id)
        flash_message(:notice, "#{params[:email]} has been invited.")
      end
      redirect_to :back
    end

    def change_role
      user_to_change = User.find(params[:user][:id])
      if @user == user_to_change
        flash_message(:error, I18n.t(:failure_change_role))
      else
        user_to_change.update_attribute(:role, params[:user][:role])
        flash_message(:notice, I18n.t(:success_change_role))
      end
      redirect_to :back
    end

    def destroy
      user_to_be_deleted = account.users.find_by_id(params[:id])
      flash_message(:notice, "#{user_to_be_deleted.email} was deleted")
      user_to_be_deleted.destroy
      redirect_to root_path
    end
  end
end
