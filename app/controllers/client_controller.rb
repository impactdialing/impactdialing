require Rails.root.join("lib/twilio_lib")

class ClientController < ApplicationController
  before_filter :check_login, :except => [:login, :user_add, :forgot]
  before_filter :check_paid
  before_filter :redirect_to_ssl

  in_place_edit_for :campaign, :name
  
  def check_login
    redirect_to_login and return if session[:user].blank?
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
        flash_now(:error, "We could not find an account with that email address.")
      else
        user.create_reset_code!
        mailer = UserMailer.new
        mailer.reset_password(user)
        flash_message(:notice, "We emailed your password to you. Please check your spam folder in case it accidentally ends up there.")
        redirect_to :action=>"login"
      end
    end
  end

  def user_add
    @title = "My account"

    if session[:user].blank?
      @user = User.new(:account => Account.new(:domain => request.domain), role: User::Role::ADMINISTRATOR)
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
        @user.send_welcome_email
        @user.create_default_campaign
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


  def check_warning
    text = warning_text
    if !text.blank?
      flash_now(:warning, text)
    end
  end

  def check_paid
    text = unpaid_text
    if !text.blank?
      flash_now(:warning, text)
    end
    text = unactivated_text
    if !text.blank?
      flash_now(:warning, text)
    end
  end

  def index
  end

  def login
    redirect_to :action => "user_add" if session[:user]

    @breadcrumb="Login"
    @title="Join Impact Dialing"
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

  def save_s3(filepath,recording)
    require 'right_aws'
    @file_data = File.new(filepath, "r")
    extension = filepath.split(".").last
    @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
    s3 = RightAws::S3.new(@config["access_key_id"], @config["secret_access_key"])
    bucket = s3.bucket("impactdialingapp")
    s3path="#{Rails.env}/uploads/#{@user.id}/#{recording.id}.#{extension}"
    key = bucket.key(s3path)
    key.data = File.open(filepath)
    key = bucket.key(s3path)
    key.data = File.open(filepath)
    content_type=""
    content_type="audio/wav" if extension=='wav'
    content_type="audio/mpeg" if extension=='mp3'
    content_type="audio/aiff" if extension=='aiff'
    content_type="audio/aiff" if extension=='aif'
    key.put(nil, 'public-read', {'Content-type' => content_type}.merge({}))
    awsurl = "http://s3.amazonaws.com/#{bucket}/#{s3path}"
    recording.file.url = awsurl
    recording.save
    awsurl
  end

  def billing
    @breadcrumb="Billing"
    @billing_account = @user.billing_account || @user.account.new_billing_account
    @oldcc = @billing_account.cc
    if @billing_account.last4.blank?
      @tempcc = ""
      @billing_account.cc = ""
    else
      @tempcc = "xxxx xxxx xxxx #{@billing_account.last4}"
      @billing_account.cc = "xxxx xxxx xxxx #{@billing_account.last4}"
    end

    if request.post?
      @billing_account.account_id = account.id
      @billing_account.attributes = params[:billing_account]

      if @billing_account.cc==@tempcc
        @billing_account.cc = @oldcc
      else
        if @billing_account.cc.length > 4
          @billing_account.last4 = @billing_account.cc[@billing_account.cc.length-4,4]
        else
          @billing_account.last4 = @billing_account.cc
        end
        @billing_account.encyrpt_cc
      end

      name_arr=@billing_account.name.split(" ")
      fname=name_arr.shift
      lname=name_arr.join(" ").strip
      
      billing_address = {
          :name => "#{@user.fname} #{@user.lname}",
          :address1 => @billing_account.address1 ,
          :zip =>@billing_account.zip,
          :city     => @billing_account.city,
          :state    => @billing_account.state,
          :country  => 'US'
      }
        
      if @billing_account.cardtype=="telecheck"
                
       linkpoint_options = {
         :order_id => "",
         :address => {}, 
         :address1 => billing_address, 
         :billing_address => billing_address, 
         :ip=>"127.0.0.1", 
         :telecheck_account => @billing_account.checking_account_number,
         :telecheck_routing => @billing_account.bank_routing_number,
         :telecheck_checknumber => params[:check_number], 
         :telecheck_dl => @billing_account.drivers_license_number, 
         :telecheck_dlstate => @billing_account.drivers_license_state, 
         :telecheck_accounttype => @billing_account.checking_account_type
       }

         response = BILLING_GW.purchase(1, nil, linkpoint_options)
         logger.info response.inspect

         if response.params["approved"]=="SUBMITTED"
           flash_message(:notice, "eCheck verified.")
           @billing_account.save
           account.update_attribute(:card_verified, true)
           redirect_to :action=>"index"
           return
         else
           flash_now(:error, "There was a problem validating your eCheck.  Please contact support for help. Error #{response.params["error"]}")
         end

      else
        # test an auth to make sure this card is good.
        creditcard = ActiveMerchant::Billing::CreditCard.new(
          :number     => @billing_account.decrypt_cc,
          :month      => @billing_account.expires_month,
          :year       => @billing_account.expires_year,
          :type       => @billing_account.cardtype,
          :first_name => fname,
          :last_name  => lname,
          :verification_value => params[:code]
        )

        if !creditcard.valid?
          if creditcard.expired?
            flash_now(:error, "The card expiration date you entered was invalid. Please try again.")
            @billing_account.cc = ""
          else
            flash_now(:error, "The card number or security code you entered was invalid. Please try again.")
            @billing_account.cc = ""
          end
          return
        end


        options = {:address => {}, :address1 => billing_address, :billing_address => billing_address, :ip=>"127.0.0.1", :order_id=>""}
        response = BILLING_GW.authorize(1, creditcard,options)
        logger.info response.inspect

        if response.success?
          flash_message(:notice, "Card verified.")
          @billing_account.save
          account.update_attribute(:card_verified, true)
          redirect_to :action=>"index"
          return
        else
          flash_now(:error, "There was a problem validating your credit card.  Please email info@impactdialing.com for further support.")
        end
      end

    end

  end

  def policies
    render 'home/policies'
  end

  private
  def stream_csv
    filename = params[:action] + ".csv"

    #this is required if you want this to work with IE
    if request.env['HTTP_USER_AGENT'] =~ /msie/i
      headers['Pragma'] = 'public'
      headers["Content-type"] = "text/plain"
      headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      headers['Expires'] = "0"
    else
      headers["Content-Type"] ||= 'text/csv'
      headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
    end

    render :text => Proc.new { |response, output|
      csv = CSV.new(output, :row_sep => "\r\n")
      yield csv
    }
  end
end
