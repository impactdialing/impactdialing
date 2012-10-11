require Rails.root.join("lib/twilio_lib")

class ClientController < ApplicationController
  protect_from_forgery :except => [:billing_updated, :billing_success]
  before_filter :authenticate_api
  before_filter :check_login, :except => [:login, :user_add, :forgot]
  before_filter :check_paid

  def authenticate_api
    unless params[:api_key].blank?
      @account = Account.find_by_api_key(params[:api_key])
      return if @account.nil?
      @user = @account.users.first
      session[:user] = @user.id
    end
  end


  def check_login
    if session[:user].blank?
      respond_to do |format|
        format.json { render :json => {status: 'error', code: '401' , message: 'Unauthorized'}, :status => :unauthorized }
        format.html { redirect_to login_path }
      end
      return
    end
    begin
      @user = User.find(session[:user])
      @account = @user.account
    rescue
      logout
    end
  end

  def current_user
    @user
  end

  def account
    current_user.try(:account)
  end

  def redirect_to_login
    redirect_to login_path
  end

  def forgot
    if request.post?
      user = User.find_by_email(params[:email])
      if user.blank?
        flash_now(:error, "We could not find an account with that email address")
      else
        user.create_reset_code!
        Resque.enqueue(ResetPasswordEmailJob, user.id)
        flash_message(:notice, "We emailed your password to you. Please check your spam folder in case it accidentally ends up there.")
        redirect_to :action=>"login"
      end
    end
  end

  def caller_password
    password = params[:caller_password]
    if password.blank? || password.length < 5
      flash_message(:error, "The Account caller password can't be less than 5 characters.")
      redirect_to :back
      return
    end
    @account.update_caller_password(params[:caller_password])
    redirect_to :back
  end

  def generate_api_key
    @account.enable_api!
    redirect_to :back
  end

  def login_from_api_key
    self.current_user = Account.find_by_api_key(params[:api_key]) unless params[:api_key].empty?
  end


  def user_add
    if session[:user].blank?
      @user = User.new(:account => Account.new(:domain_name => request.domain), role: User::Role::ADMINISTRATOR)
    else
      @user = User.find(session[:user])
      @account = @user.account
    end

    if request.post?
      @user.attributes =  params[:user]
      if params[:fullname]!=nil
        name_arr=params[:fullname].split(" ")
        fname=name_arr.shift
        @user.fname=fname.strip if fname!=nil
        @user.lname=name_arr.join(" ").strip
      end

      if !@user.new_record? and (not @user.authenticate_with?(params[:exist_pw]))
        flash_now(:error, "Current password incorrect")
        return
      else
        @user.save
      end

      if @user.valid?
        @user.create_recurly_account_code
        if session[:user].blank?
          message = "Your account has been created."
          session[:user]=@user.id
          flash_message(:notice, message)
          flash_message(:kissmetrics, "Signed Up")
          redirect_to :action=>"welcome"
          return
        else
          message="Your account has been updated."
        end
        session[:user]=@user.id
        redirect_to :action=>"index"
        flash_message(:notice, message)
      end
    end
  end

  def check_paid
    if current_user && !current_user.account.card_verified?
      flash_now(:warning, I18n.t(:unpaid_text, :billing_link => '<a href="' + white_labeled_billing_link(request.domain) + '">Click here to verify a credit card.</a>').html_safe)
    end
  end

  def index
  end

  def login
    if session[:user]
      redirect_to :action => "user_add"
      return
    end

    @user = User.new {params[:user]}
    if !params[:user].blank?
      user_add
    end

    if !params[:email].blank?
      @user = User.authenticate(params[:email], params[:password])
      if @user.blank?
        flash_now(:error, "The email or password you entered was incorrect. Please try again.")
        @user = User.new {params[:user]}
      else
        session[:user]=@user.id
        flash_message(:kissmetrics, "Signed In")
        redirect_to :action=>"index"
        return
      end
    end

  end

  def logout
    session[:user]=nil
    redirect_to_login
  end

  def recording_add
    if request.post?
      @recording = @account.recordings.new(params[:recording])
      if params[:recording][:file].blank?
        flash_now(:error, "You must choose a recording to upload.")
        return
      end
      if params[:recording][:name].blank?
        flash_now(:error, "You must enter a name for the voicemail.")
        return
      end
      @recording.save!
      campaign = Campaign.find(params[:campaign_id])
      campaign.update_attribute(:recording, @recording)

      flash_message(:notice, "Vociemail added.")
      redirect_to client_campaign_path(params[:campaign_id])
      return
    else
      @recording = @account.recordings.new
    end
  end

  def recharge
     @account=@user.account

     if request.put?
       @account.update_attributes(params[:account])
       flash_message(:notice, "Autorecharge settings saved")
       redirect_to :action=>"billing"
       return
     end

     @account.autorecharge_trigger=20.to_f if @account.autorecharge_trigger.nil?
     @account.autorecharge_amount=40.to_f if @account.autorecharge_amount.nil?
     @recharge_options=[]
     @recharge_options.tap{
      10.step(500,10).each do |n|
        @recharge_options << ["$#{n}",n.to_f]
       end
     }
   end

   def billing_updated
     # return url from recurly.js account update
     flash_message(:notice, "Billing information updated")
     redirect_to :action=>"billing"
   end

   def cancel_subscription
     if request.post?
       @user.account.cancel_subscription
       flash_message(:notice, "Subscription cancelled")
       redirect_to :action=>"billing"
     end
   end

   def billing_success
     # return url from recurly hosted subscription form
     @user.account.sync_subscription
     redirect_to :action=>"billing"
   end

   def billing_form
     @account_code=@user.account.recurly_account_code
     @billing_info = Recurly::Account.find(@account_code).billing_info
   end

   def update_billing
     @account_code=@user.account.recurly_account_code
     @billing_info = Recurly::Account.find(@account_code).billing_info
   end

   def add_to_balance
     if request.post?
       new_payment=Payment.charge_recurly_account(@user.account, params[:amount], "Add to account balance")
       if new_payment.nil?
         #charge failed
          flash_now(:error, "There was a problem charging your credit card.  Please try updating your billing information or contact support for help.")
       else
         #charge succeeded
         flash_message(:notice, "Payment successful.")
         redirect_to :action=>"billing"
         return
       end
     end
     recurly_account = Recurly::Account.find(@user.account.recurly_account_code)
     @billing_info = recurly_account.billing_info
   end

   def billing
     @balance=@user.account.current_balance
     @has_billing_info = !Recurly::Account.find(@user.account.recurly_account_code).billing_info.nil?
   end

   def update_billing_quantity
     if request.post?
       subscription = Recurly::Subscription.find(@user.account.recurly_subscription_uuid)
       subscription.update_attributes(
         :quantity  => params[:num_callers],
         :timeframe => 'now'       # Update immediately.
       )
       @user.account.update_attribute(:subscription_count, params[:num_callers])
       flash_message(:notice, "Number of callers updated.")
       redirect_to :action=>"billing"
     end
   end

   def new_subscription
     render :layout=>"recurly"
   end

  def policies
    render 'home/policies'
  end
end
