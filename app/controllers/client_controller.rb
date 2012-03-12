require Rails.root.join("lib/twilio_lib")

class ClientController < ApplicationController
  protect_from_forgery :except => :billing_updated
  before_filter :check_login, :except => [:login, :user_add, :forgot]
  before_filter :check_paid
  before_filter :redirect_to_ssl

  layout "client"
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
    @breadcrumb = "Password Recovery"
    if request.post?
      user = User.find_by_email(params[:email])
      if user.blank?
        flash_now(:error, "We could not find an account with that email address")
      else
        user.create_reset_code!
        #Postoffice.password_recovery(u).deliver

        begin
          emailText="Click here to reset your password<br/> #{ reset_password_url(:reset_code => user.password_reset_code) }"
          u = Uakari.new(MAILCHIMP_API_KEY)

          response = u.send_email({
              :track_opens => true,
              :track_clicks => true,
              :message => {
                  :subject => "ImpactDialing.com password recovery",
                  :html => emailText,
                  :text => emailText,
                  :from_name => 'Impact Dialing',
                  :from_email => 'email@impactdialing.com',
                  :to_email => [user.email]
              }
          })
          rescue Exception => e
            logger.error(e.inspect)
        end

        flash_message(:notice, "We emailed your password to you. Please check your spam folder in case it accidentally ends up there.")
        redirect_to :action=>"login"
      end
    end
  end

  def user_add
    @breadcrumb = "My Account"
    @title = "My Account"

    if session[:user].blank?
      @user = User.new(:account => Account.new(:domain => request.domain))
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
        @user.create_promo_balance
        @user.create_recurly_account_code
        if session[:user].blank?
          message = "Your account has been created."
          session[:user]=@user.id
          flash_message(:notice, message)          
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
    @breadcrumb = nil
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
        redirect_to :action=>"index"
        return
      end
    end

  end

  def logout
    session[:user]=nil
    redirect_to_login
  end

  def call_now
    campaign = Campaign.find(params[:id])
    if !phone_number_valid(params[:num])
      flash_now(:error, "Phone number entered is invalid!")
    elsif list = VoterList.find_all_by_campaign_id(params[:id]).length==0
      flash_now(:error, "No voter list available")
    else
      list = VoterList.find_all_by_campaign_id(params[:id]).first
      num = params[:num].gsub(/[^0-9]/, "")
      voter = Voter.find_by_campaign_id_and_Phone(params[:id], num)
      voter.dial_predictive
      flash_message(:notice, "Calling you now!")
    end

    redirect_to client_campaign_path(campaign)
    return
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

  def robo_session_start
    @campaign = Campaign.find(params[:campaign_id])
    @caller = Caller.find(params[:caller_id])
    @session = CallerSession.new
    @session.caller_number = phone_format("Robo")
    @session.caller_id = @caller.id
    @session.campaign_id = @campaign.id
    @session.save
    @session.starttime = Time.now
    @session.available_for_call = true
    @session.on_call = true
    @session.save
    flash_message(:notice, "Robo session started")
    redirect_to client_campaigns_path(params[:campaign_id])
  end

  def robo_session_end
    require 'net/http'
    require 'net/https'
    require 'uri'

    sessions = CallerSession.find_all_by_caller_id_and_on_call(params[:caller_id],true)
    sessions.each do |session|
      session.endtime = Time.now
      session.available_for_call = false
      session.on_call = false
      session.save
    end
    flash_message(:notice, "Robo session ended")
    redirect_to client_campaigns_path(params[:campaign_id])
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
  
  def billing_success
    # return url from recurly hosted subscription form
    @user.account.sync_subscription
    redirect_to :action=>"billing"
  end
  
  def update_billing
    @account_code=@user.account.recurly_account_code
    @billing_info = Recurly::Account.find(@account_code).billing_info
    render :layout=>nil
  end
  
  def add_to_balance
    if request.post?
      charge_uuid=Payment.charge_recurly_account(@user.account.recurly_account_code, params[:amount], "Add to account balance")
      if charge_uuid.nil?
        #charge failed
         flash_now(:error, "There was a problem charging your credit card.  Please try updating your billing information or contact support for help.")
      else
        #charge succeeded
        @user.new_payment(params[:amount], "Add to account balance", charge_uuid)
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
    @trial=@user.account.trial?
  end
  
  def new_subscription
    render :layout=>"recurly"
  end

  def billing_old
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

  def campaign_hash_delete
    #    cache_delete("avail_campaign_hash")
    ActiveRecord::Base.connection.execute("update caller_sessions set available_for_call=0")
    @campaign = account.campaigns.find_by_id(params[:id])
    @campaign.end_all_calls(TWILIO_ACCOUNT,TWILIO_AUTH,APP_URL)
    @sessions = CallerSession.find_all_by_campaign_id_and_on_call(params[:id],1)
    @sessions.each do |sess|
      sess.on_call = false
      sess.endtime = Time.now if sess.endtime==nil
      sess.save
    end
    flash_message(:notice, "Dialer Reset.  Callers must call back in.")
    redirect_to client_campaigns_path(params[:id])
    return
  end

  def voter_delete
    @voter = account.voters.find_by_id(params[:id])
    if !@voter.blank?
      @voter.active = false
      @voter.save
    end
    flash_message(:notice, "Voter deleted")
    redirect_to client_campaigns_path(@voter.campaign_id)
    return
  end

  def voter_add
    @campaign = Campaign.find(params[:campaign_id])
    @voter = account.voters.find_by_id(params[:id]) || Voter.new
    if @voter.new_record?
      @label="Add Voter"
    else
      @label="Edit Voter"
    end
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},{@campaign.name=>client_campaign_path(@campaign)}, @label]
    if request.post?
      if params[:voterList]=="0" && params[:new_list_name].blank?
        flash_now(:error, "List name cannot be blank")
        return
        elseif params[:voterList]=="0"
        l = account.voter_lists.find_by_name(params[:new_list_name])
        if !l.blank?
          flash_now(:error, "List name cannot be blank")
          return
        end
      end
      if params[:voterList]=="0"
        list = VoterList.new
        list.campaign_id = @campaign.id
        list.name = params[:new_list_name]
        list.account_id = account.id
        list.save
      else
        list = VoterList.find(params[:voterList])
      end

      @voter.voter_list_id = list.id
      @voter.account_id = account.id
      @voter.campaign_id = @campaign.id
      @voter.update_attributes(params[:voter])
      if @voter.valid?
        @voter.save
        flash_message(:notice, "Voter saved")
        redirect_to client_campaigns_path(@campaign.id)
        return
      end
    end

  end

  def campaign_clear_calls
    ActiveRecord::Base.connection.execute("update voters set result=NULL, status='not called' where campaign_id=#{params[:id]}")
    #    ActiveRecord::Base.connection.execute("delete from voter_results where campaign_id=#{params[:id]}")
    flash_message(:notice, "Calls cleared")
    redirect_to client_campaigns_path(params[:id])
    return
  end

  def scripts
    @breadcrumb="Scripts"
    @scripts = @user.account.scripts.active.manual.paginate :page => params[:page], :order => 'name'
  end

  def script_add
    if params[:id].blank?
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Add Script"]
    else
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Edit Script"]
    end
    @script = account.scripts.find_by_id(params[:id])
    @fields = ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"].concat(@script ? @script.account.custom_voter_fields.map(&:name) : [])
    @numResults = 0
    if @script!=nil
      for i in 1..NUM_RESULT_FIELDS do
        @numResults+=1 if !eval("@script.result_set_#{i}").blank?
      end
      @numNotes = 0
      for i in 1..NUM_RESULT_FIELDS do
        @numNotes+=1 if !eval("@script.note_#{i}").blank?
      end
    else
      @numResults = 1
      @numNotes = 0
    end
    if @script==nil
      @script = Script.new
      @script.name = "Untitled Script"
    end
    if @script.new_record?
      @label = "New script"
    else
      @label = "Add script"
    end
    if @script.incompletes!=nil
      begin
        @incompletes = JSON.parse(@script.incompletes)
      rescue
        @incompletes={}
      end
    else
      @incompletes={}
    end

    if @script.voter_fields!=nil
      begin
        @voter_fields = eval(@script.voter_fields)
      rescue
        @voter_fields=[]
      end
    else
      @voter_fields=[]
    end

    if request.post?
      @script.update_attributes(params[:script])
      for r in 1..16 do
        @script.attributes = {"result_set_#{r}"=>nil}
      end
      numResults = params[:numResults]
      for r in 1..numResults.to_i do
        thisResults={}
        thisResults["name"]=eval("params[:qname_#{r}]")
        for i in 1..99 do
          thisKeypadval = eval("params[:keypad_#{r}_#{i}]" )
          if !thisKeypadval.blank? && !isnumber(thisKeypadval)
            flash_now(:error, "Keypad value for call results #{r} entered '#{thisKeypadval}' must be numeric")
            return
          end
        end

#        for i in 1..99 do
          #@script.attributes = { "keypad_#{r}_#{i}" => nil }
 #         thisResults["keypad_#{i}"] = nil
#        end

        for i in 1..99 do
          thisResult = eval("params[:text_#{r}_#{i}]")
          thisKeypadval = eval("params[:keypad_#{r}_#{i}]" )
          if !thisResult.blank? && !thisKeypadval.blank?
            thisResults["keypad_#{i}"] =  thisResult
          end
        end
#        logger.info "Done with #{r}: #{thisResults.inspect}"
        @script.attributes =   { "result_set_#{r}" => thisResults.to_json }
      end

      for i in 1..NUM_RESULT_FIELDS do
        @script.attributes = { "note_#{i}" => nil }
        thisNote = eval("params[:note_#{i}]")
        @script.attributes = { "note_#{i}" => thisNote } if !thisNote.blank?
      end

      all_incompletes={}
      for i in 1..NUM_RESULT_FIELDS do
        this_incomplete = eval("params[:incomplete_#{i}_]")
        if this_incomplete.nil?
          all_incompletes[i]=[]
        else
          all_incompletes[i]=this_incomplete
        end
      end
      @script.incompletes = all_incompletes.to_json

      if @script.valid?

        if params[:voter_field]
          @script.voter_fields = params[:voter_field].to_json
        else
          @script.voter_fields = nil
        end

        @script.account_id = account.id
        @script.save
        flash_message(:notice, "Script saved")
        redirect_to :action=>"scripts"
        return
      end
    end

  end

  def voter_view
    @campaign = Campaign.find_by_id_and_account_id(params[:campaign_id],account.id)
    @breadcrumb=[{"Campaigns"=>client_campaigns_path},{@campaign.name => client_campaign_path(@campaign)},"View Voters"]
    @campaign = account.campaigns.find_by_id(params[:campaign_id])
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},{"#{@campaign.name}"=>client_campaign_path(@campaign)},"View Voters"]
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id} and voter_list_id in (#{@campaign.voter_lists.collect{|c| c.id.to_s + ","}}0)", :order => 'LastName,FirstName,Phone'
  end

  def reports
    if params[:id].blank?
      @breadcrumb = "Reports"
      @campaigns = account.campaigns.manual
    else
      @campaign = Campaign.find(params[:id])
      @breadcrumb=[{"Reports"=>"/client/reports"},@campaign.name]
    end
  end

  def test
    if params[:id]=="drop_all_caller"
      c = Campaign.find(38)
      c.end_all_callers(TWILIO_ACCOUNT, TWILIO_AUTH, APP_URL)
      flash_message(:notice, "Callers dropped")
    elsif params[:id]=="add_caller_5"
      flash_message(:notice, "5 Test callers added")
      (1..5).each do |i|
        t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
        a = t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => APP_NUMBER, 'Called' => TEST_CALLER_NUMBER, 'Url'=>"#{APP_URL}/callin?test=1"})
      end
    elsif params[:id]=="add_caller_15"
      flash_message(:notice, "15 Test callers added")
      (1..15).each do |i|
        t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
        a = t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => APP_NUMBER, 'Called' => TEST_CALLER_NUMBER, 'Url'=>"#{APP_URL}/callin?test=1"})
      end
    elsif params[:id]=="add_caller"
      flash_message(:notice, "Test caller added")
      t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      a = t.call("POST", "Calls", {'Timeout'=>"15", 'Caller' => APP_NUMBER, 'Called' => TEST_CALLER_NUMBER, 'Url'=>"#{APP_URL}/callin?test=1"})
    end
    redirect_to :action=>"report_realtime", :id=>"38"
  end

  def report_realtime
    check_warning
    if params[:id].blank?
      @breadcrumb = "Reports"
    else
      @campaign= account.campaigns.find_by_id(params[:id])
      if @campaign.blank?
        render :text=>"Unauthorized"
        return
      end
      @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Realtime Report"]
    end
    #    require "#{Rails.root.to_s}/app/models/caller_session.rb"
    #    require "#{Rails.root.to_s}/app/models/caller.rb"
  end

  def report_realtime_new
    check_warning
    if params[:timeframe].blank?
      @timeframe = 10
    else
      @timeframe = params[:timeframe].to_i
    end
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"New Realtime Report"]
  end

  def update_report
    #    Rails.logger.silence do
    # CallerSession
    # Caller
    if params[:timeframe].blank?
      @timeframe = 10
    else
      @timeframe = params[:timeframe].to_i
    end

    # if !params[:clear].blank?
    #   cache_delete("avail_campaign_hash")
    # end
    # @avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    @campaign = account.campaigns.find_by_id(params[:id])
    render :layout=>false
    #    end
  end

  def report_overview
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end

    set_report_date_range
    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Overview Report"]
    sql = "#select distinct status from call_attempts

    select
    count(*) as cnt,
    case WHEN ca.status='Call abandoned' THEN 'Call abandoned'
      WHEN ca.status='Hangup or answering machine' THEN 'Hangup or answering machine'
      WHEN ca.status='No answer' THEN 'No answer'
      WHEN ca.status='No answer busy signal' THEN 'Busy signal'
      ELSE ca.status
      END AS result

      from
      call_attempts ca
      where ca.campaign_id=#{@campaign.id}
      and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
      and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
      group by
      case WHEN ca.status='Call abandoned' THEN 'Call abandoned'
        WHEN ca.status='Hangup or answering machine' THEN 'Hangup or answering machine'
        WHEN ca.status='No answer' THEN 'No answer'
        WHEN ca.status='No answer busy signal' THEN 'Busy signal'
        ELSE ca.status
        END
        order by count(*) desc"
        @records = ActiveRecord::Base.connection.execute(sql)
        @total=0
        @records.each do |r|
          @total = @total + r[0].to_i
        end
        @records.data_seek(0)

        @voters_to_call = @campaign.voters_count("not called",false)
        @voters_called = @campaign.voters_called
        @totalvoters = @voters_to_call.length + @voters_called.length

        @call_attempts = CallAttempt.find_all_by_campaign_id(@campaign.id)
        @caller_sessions = CallerSession.find_all_by_campaign_id(@campaign.id)

        @talkmins=0
        @call_attempts.each do |attempt|
          @talkmins += attempt.minutes_used
        end
        @callerMins=0
        @caller_sessions.each do |session|
          @callerMins += session.minutes_used
        end

  end

  def report_overview_old
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    @script=@campaign.script
    extra = ""

    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Answereds Call Report"]

    set_report_date_range

    sql = "
        SELECT result_json
        FROM call_attempts
        where campaign_id=#{@campaign.id}
        and result_json IS NOT NULL
        and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
        and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'  #{extra}
        "
        logger.info sql

        @records = ActiveRecord::Base.connection.execute(sql)

        @json_fields=[]
        @results_hash={}
        @names_hash={}
        @records.each do |r|
          this_record=YAML.load(r[0])
          @json_fields = @json_fields | this_record.keys
          this_record.keys.each do |f|
            if this_record[f].index("name")
            end
#            @names_hash
          end
        end
        # render :text=>json_fields.inspect
        # return

        @json_fields.each do |f|
          @results_hash[f]={}
          @records.data_seek(0)
          @records.each do |r|
            this_record=YAML.load(r[0])
            if this_record.keys.index(f)
              this_result = this_record[f]
              # render :text=>this_record.inspect
              # return
#              this_result = this_records_fields[this_records_fields.index(f)]
              @results_hash[f][this_result]=0 if !@results_hash[f].keys.index(this_result)
              @results_hash[f][this_result] += 1
            end
          end
        end

#        render :text=>@results_hash.inspect
#        return


        @total=0
        @records.each do |r|
          @total = @total + r[0].to_i
        end
        @records.data_seek(0)

        @voters_to_call = @campaign.voters_count("not called",false)
        @voters_called = @campaign.voters_called
        @totalvoters = @voters_to_call.length + @voters_called.length

  end

  # def show_memcached
  #   @avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
  # end
  def script_delete
    @script = account.scripts.find_by_id(params[:id])
    if !@script.blank?
      @script.active=false
      @script.save
    end
    flash_message(:notice, "Script deleted")
    redirect_to :back
  end

  def report_caller
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra = "and result is not null"
    end

    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]

    set_report_date_range
    caller_ids=CallerSession.all(:select=>"distinct caller_id", :conditions=>"campaign_id=#{@campaign.id}")
    @callers=[]
    caller_ids.each do |caller_session|
      @callers<< Caller.find(caller_session.caller_id)
    end

    @responses = Voter.all(:select=>"distinct result", :conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'")
    @num_responses = Voter.all(:conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'").length
  end

  def report_caller_overview
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra = "and result is not null"
    end

    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]

    set_report_date_range
    caller_ids=CallerSession.all(:select=>"distinct caller_id", :conditions=>"campaign_id=#{@campaign.id}")
    @callers=[]
    caller_ids.each do |caller_session|
      @callers<< Caller.find(caller_session.caller_id)
    end

  end

  def report_login

    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end
    if params[:type]=="1"
      extra = "and result is not null"
    end

    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Caller Report"]
    #      @logins = CallerSession.find_all_by_campagin_id(@campagin.id, :order=>"id desc")
    @logins = CallerSession.find_all_by_campaign_id(@campaign.id, :order=>"id desc")
  end

  def report_download
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end

    @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Download Report"]
    set_report_date_range

    if params[:download]=="1"
      #      attempts = CallAttempt.find_all_by_campaign_id(@campaign.id)

      subsql = "select voter_id from call_attempts ca
           join voters v on v.id=ca.voter_id
           where ca.campaign_id=#{@campaign.id} and last_call_attempt_id=ca.id
           and ca.created_at > '#{@from_date.strftime("%Y-%m-%d")}'
           and ca.created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
      "
      voters = ActiveRecord::Base.connection.execute(subsql)
      voter_ids = []
      voters.each do |a|
        voter_ids << a[0]
      end
      if voter_ids.length==0
        voter_subq = "0"
      else
        voter_subq = voter_ids.join(",")
      end

      sql = <<-EOSQL
        select
        ca.result, ca.result_digit , v.Phone, v.CustomID, v.LastName, v.FirstName, v.MiddleName, v.Suffix, v.Email, c.pin, c.name,  c.email, ca.status, ca.connecttime, ca.call_end, v.last_call_attempt_id=ca.id as final , ca.result_json, f.CustomID, f.LastName, f.FirstName, f.MiddleName, f.Suffix, f.Email, family_id_answered, cs.caller_number
        from call_attempts ca
        join voters v on v.id=ca.voter_id
        left outer join callers c on c.id=ca.caller_id
        left outer join caller_sessions cs on cs.id=ca.caller_session_id
        left outer join families f on f.id=v.family_id_answered
        where
        ca.campaign_id=#{@campaign.id}
        and v.id in (#{voter_subq})
        order by v.id asc, ca.id asc
      EOSQL
      attempts = ActiveRecord::Base.connection.execute(sql)
      logger.info "attempts: #{attempts}"
      json_fields=[]
      attempts.each do |a|
        if json_fields.empty? && a[16]!=nil
          json_fields = YAML.load(a[16]).keys
        end
      end
      attempts.data_seek(0)

      csv_string = CSV.generate do |csv|
        #            csv << ["result", "result digit" , "voter phone", "voter id", "voter last", "voter first", "voter middle", "voter suffix", "voter email","caller pin", "caller name",  "caller email","status", "call start", "call end", "number attempts"]
        #csv << ["id", "LastName", "FirstName", "MiddleName", "Suffix", "Phone", "Result", "Caller Name", "Status", "Call Start", "Call End", "Number Calls"] + json_fields #+ ["fam_id", "fam_LastName", "fam_FirstName", "fam_MiddleName", "fam_Suffix", "fam_Email"]
        csv << ["id", "LastName", "FirstName", "MiddleName", "Suffix", "Phone", "Caller Name", "Caller Phone", "Status", "Call Start", "Call End", "Number Calls"] + json_fields #+ ["fam_id", "fam_LastName", "fam_FirstName", "fam_MiddleName", "fam_Suffix", "fam_Email"]
        num_call_attempts=0
        attempts.each do |a|
          num_call_attempts+=1
          #logger.info "a[15]: #{a[15]}"
          if a[15]=="1"
            #final attempt
            #logger.info a.inspect
            json_to_add=[]
            if a[16].blank?
              json_fields.each do |j|
                json_to_add << ""
              end
            else
              json=YAML.load(a[16])
              json_fields.each do |j|
                if json.keys.index(j)
                  json_to_add << json[j]
                else
                  json_to_add << ""
                end
              end
            end
            #csv << [a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10],a[11],a[12],a[13],a[14],a[15],num_call_attempts]
            #csv << [a[3],a[4],a[5],a[6],a[7],a[2],a[0],a[10],a[12],a[13],a[14],num_call_attempts]  + json_to_add + [a[17],a[18],a[19],a[20],a[21]]
            if a[23]==0 || a[23]=="" || a[23]==nil || a[23]=="0"
              #no fam
              #logger.info "no fam"
              csv << [a[3],a[4],a[5],a[6],a[7],a[2],a[10],a[24],a[12],a[13],a[14],num_call_attempts]  + json_to_add #+ [a[17],a[18],a[19],a[20],a[21]]
            else
              #fam
              #logger.info "fam: #{a[23]}"
              csv << [a[17],a[18],a[19],a[20],a[7],a[2],a[10],a[24],a[12],a[13],a[14],num_call_attempts]  + json_to_add
            end

            num_call_attempts=0
          end
        end
      end
      send_data csv_string, :type => "text/csv",  :filename=>"report.csv", :disposition => 'attachment'
      return
    end

  end

  def report_real
    check_warning
    if params[:id].blank?
      @breadcrumb = "Reports"
    else
      @campaign = account.campaigns.find_by_id(params[:id])
      if @campaign.blank?
        render :text=>"Unauthorized"
        return
      end
      @breadcrumb=[{"Reports"=>"/client/reports"},{"#{@campaign.name}"=>"/client/reports/#{@campaign.id}"},"Realtime Report"]
    end
  end

  def update_report_real
    if params[:timeframe].blank?
      @timeframe = 10
    else
      @timeframe = params[:timeframe].to_i
    end

    # if !params[:clear].blank?
    #   cache_delete("avail_campaign_hash")
    # end
    # @avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
    @campaign = account.campaigns.find_by_id(params[:id])
    if @campaign.nil?
      render :text=>"Campaign not found or access not permitted"
      return
    end
    render :layout=>false
  end

  def set_report_date_range
    begin
      if params[:from_date]
        @from_date=Date.strptime(params[:from_date], "%m/%d/%Y")
        @to_date = Date.strptime(params[:to_date], "%m/%d/%Y")
      else
        firstCall = CallerSession.find_by_campaign_id(@campaign.id,:order=>"id asc", :limit=>"1")
        lastCall = CallerSession.find_by_campaign_id(@campaign.id,:order=>"id desc", :limit=>"1")
        if !firstCall.blank?
          @from_date  = firstCall.created_at
        end
        if !lastCall.blank?
          @to_date  = lastCall.created_at
        end
      end
    rescue
      #just use the defaults below
    end

    @from_date = Date.parse("2010/01/01") if @from_date==nil
    @to_date = DateTime.now if @to_date==nil
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
