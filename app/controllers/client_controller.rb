class ClientController < ApplicationController
  before_filter :check_login, :except => [:login,:user_add, :forgot]
  before_filter :check_paid
  before_filter :redirect_to_ssl
  skip_before_filter :verify_authenticity_token, :only => [:login]

  layout "client"
  in_place_edit_for :campaign, :name

  def check_login
    redirect_to_login and return if session[:user].blank?
    begin
      @user = User.find(session[:user])
    rescue
      logout
    end
  end
  
  def current_user
    @user
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
        user.create_reset_code
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
      @user = User.new
    else
      @user = User.find(session[:user])
    end

    if request.post?
      @user.attributes =  params[:user].merge(:domain => request.domain)
      if params[:fullname]!=nil
        name_arr=params[:fullname].split(" ")
        fname=name_arr.shift
        @user.fname=fname.strip if fname!=nil
        @user.lname=name_arr.join(" ").strip
      end

      if false && @user.new_record? && params[:tos].blank?
        flash_now(:error, "You must agree to the Terms of Service to create an account.")
        return
      elsif !@user.new_record? and (not @user.authenticate_with?(params[:exist_pw]))
        flash_now(:error, "Current password incorrect")
        return
      end

      if @user.valid?
        @user.send_welcome_email if @user.new_record?
        @user.save

        @caller = Caller.new
        @caller.name = "Default Caller"
        @caller.multi_user = true
        @caller.user_id = @user.id
        @caller.save

        if Script.find_by_name_and_user_id("Voter ID Example",@user.id)==nil
          @script = Script.new
          @script.name = "Voter ID Example"
          @rs={}
          @rs["keypad_1"]="Strong supportive"
          @rs["keypad_2"]="Lean supportive"
          @rs["keypad_3"]="Undecided"
          @rs["keypad_4"]="Lean opposed"
          @rs["keypad_5"]="Strong opposed"
          @rs["keypad_6"]="Refused"
          @rs["keypad_7"]="Not home/call back"
          @rs["keypad_8"]="Language barrier"
          @rs["keypad_9"]="Wrong number"
          @rs["name"]="How supportive was the voter?"
          #      @rs.incompletes=["7"].to_json
          @script.result_set_1 = @rs.to_json
          @script.incompletes='{"5":[],"6":[],"1":["7"],"7":[],"2":[],"8":[],"3":[],"9":[],"4":[],"10":[]}'
          @script.name = "Political Example Script"
          @script.note_1 = "Email"
          @numResults = 1
          @numNotes = 1
          @script.voter_fields='["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Email"]'
          @script.script = <<-EOS
Hi, is ___ there?

My name's ___ and I'm a volunteer with the such-and-such campaign.

I'm voting for such-and-such because...

Can we count on you to vote for such-and-such?
          EOS
          @script.active = 1
          @script.user_id = @user.id
          @script.save
        end

        if false && Script.find_by_name_and_user_id("Voter ID Example",@user.id)==nil
          @script = Script.new
          @script.name = "Voter ID Example"
          @script.keypad_1 = "Strong supportive"
          @script.keypad_2 = "Lean supportive"
          @script.keypad_3 = "Undecided"
          @script.keypad_4 = "Lean opposed"
          @script.keypad_5 = "Strong opposed"
          @script.keypad_6 = "Refused"
          @script.keypad_7 = "Not home/call back"
          @script.keypad_8 = "Language barrier"
          @script.keypad_9 = "Wrong number"
          @script.incompletes = ["7"].to_json
          @script.script = "Hi, is ___ there?

          My name's ___ and I'm a volunteer with the such-and-such campaign.

          I'm voting for such-and-such because...

          Can we count on you to vote for such-and-such?"
          @script.active = 1
          @script.user_id = @user.id
          @script.save
        end

        # @script = Script.new
        #       @script.name="GOTV Example"
        #       @script.keypad_1="Will vote early"
        #       @script.keypad_2="Will vote on election day"
        #       @script.keypad_3="Already voted"
        #       @script.keypad_4="Will not vote"
        #       @script.keypad_5="Not a supporter"
        #       @script.keypad_6="Refused"
        #       @script.keypad_7="Not home/call back"
        #       @script.keypad_8="Language barrier"
        #       @script.keypad_9="Wrong number"
        #       @script.incompletes=["7"].to_json
        #       @script.script="Hi, I'm a volunteer with the such-and-such campaign.
        #
        #       I'm voting for such-and-such because...
        #
        #       Can we count on you to vote for such-and-such?"
        #       @script.active = 1
        #       @script.user_id = @user.id
        #       @script.save

        if false && Script.find_by_name_and_user_id("Fundraising Example",@user.id)==nil
          @script = Script.new
          @script.name="Fundraising Example"
          @script.keypad_1="Gave money"
          @script.keypad_2="Requested remit"
          @script.keypad_3="Will give later"
          @script.keypad_4="Won't give again"
          @script.keypad_5="Refused to talk"
          @script.keypad_6="Not home"
          @script.keypad_7="Call back"
          @script.keypad_8="Wrong number"
          @script.incompletes=["7","6"].to_json
          @script.script= <<-EOS
          Hi, is ___ there?

          My name's ___, and I'm calling from the Organization to Make the World Better.

          Will you donate to help our work?
          EOS
          @script.active = 1
          @script.user_id = @user.id
          @script.save
        end

        if false && Script.find_by_name_and_user_id("Sales Example",@user.id)==nil
          @script = Script.new
          @script.name="Sales Example"
          @script.keypad_1="Bought the product"
          @script.keypad_2="Wants more info"
          @script.keypad_3="Not interested"
          @script.keypad_4="Refused to talk"
          @script.keypad_5="Not home"
          @script.keypad_6="Call back"
          @script.keypad_7="Wrong number"
          @script.incompletes=["5","6"].to_json
          @script.script= <<-EOS
          Hi, is ___ there?

          Hi! My name's ___. I'm calling from Widgets, Inc. We have some great new widgets in stock.

          Do you want to buy a widget?
          EOS
          @script.active = 1
          @script.user_id = @user.id
          @script.save
        end

        if session[:user].blank?
          message = "Your account has been created"
        else
          message="Your account has been updated"
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
      end
    end

  end

  def logout
    session[:user]=nil
    redirect_to_login
  end

  def callers
    @breadcrumb="Callers"
    @callers = Caller.where(:active => true, :user_id => @user.id).order(:name).paginate(:page => params[:page])
  end

  def caller_add
    @breadcrumb=[{"Callers"=>"/client/callers"},"Add Caller"]
    @caller = Caller.find_by_id_and_user_id(params[:id],@user.id) || Caller.new
    if @caller.new_record?
      @label="Add caller"
    else
      @label="Edit caller"
    end
    if request.post?
      @caller.update_attributes(params[:callers])
      if @caller.valid?
        @caller.user_id = @user.id
        @caller.save

        # add to campaigns with all callers
        all_callers = Caller.find_all_by_user_id_and_active(@user.id,1)
        all_campaings = Campaign.find_all_by_user_id_and_active(@user.id,1)
        all_campaings.each do |campaign|
          if campaign.callers.length >= (all_callers.length)-1
            campaign.callers << @caller
          end
        end
        flash_message(:notice, "Caller saved")
        redirect_to :action=>"callers"
        return
      end
    end

  end

  def caller_delete
    @caller = Caller.find_by_id_and_user_id(params[:id],@user.id)
    if !@caller.blank?
      @caller.active = false
      @caller.save
    end
    flash_message(:notice, "Caller deleted")
    redirect_to :action=>"callers"
    return
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

  def campaign_add
    @breadcrumb=[{"Campaigns"=>"/client/campaigns"},"Add Campaign"]
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id) || Campaign.new
    if @campaign.new_record?
      @label="Add campaign"
    else
      @label="Edit campaign"
    end
    newrecord = @campaign.new_record?
    if request.post?
      last_caller_id = @campaign.caller_id
      @campaign.update_attributes(params[:campaign])
      code=""
      if @campaign.valid?
        if !@campaign.caller_id_verified || (!@campaign.caller_id.blank? && last_caller_id != @campaign.caller_id)
          #verify this callerid
          t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
          a = t.call("POST", "OutgoingCallerIds", {'PhoneNumber'=>@campaign.caller_id, 'FriendlyName' => "Campaign #{@campaign.id}"})
          require 'rubygems'
          require 'hpricot'
          @doc = Hpricot::XML(a)
          puts @doc
          code= (@doc/"ValidationCode").inner_html
        end
        @campaign.user_id = @user.id
        if @campaign.script_id.blank?
          s = Script.find_by_user_id_and_active(@user.id,1)
          @campaign.script_id = s.id if s!=nil
        end
        @campaign.save
        if params[:listsSent]
          @campaign.voter_lists.each do |l|
            l.enabled = false
            l.save
          end
          if !params[:voter_list_ids].blank?
            params[:voter_list_ids].each do |lid|
              l = VoterList.find(lid)
              l.enabled = true
              l.save
            end
          end
        end
        if newrecord
          callers = Caller.find_all_by_user_id_and_active(@user.id,1)
          callers.each do |caller|
            @campaign.callers << caller
          end
        end
        if code.blank?
          flash_message(:notice, "Campaign saved")
        else
          flash_message(:notice, "Campaign saved.  <font color=red>Enter code #{code} when called.</font>")
        end
        redirect_to client_campaign_path(@campaign)
        return
      end
    end
  end

  def recording_add
    if request.post?
      @recording = @user.recordings.new(params[:recording])
      if params[:recording][:file].blank?
        flash_now(:error, "No file uploaded")
        return
      end
      if params[:recording][:name].blank?
        flash_now(:error, "No name entered")
        return
      end
      @recording.save!

      #path = File.join("/tmp/", name)
      #File.open(path, "wb") { |f| f.write(params[:upload]['datafile'].read) }
      #bytes = File.size(path)
      #if bytes > 1048576*15 #15MB
        #flash_now(:error, "Uploaded file is too large (max 15MB)")
        #return
      #end
      #r = Recording.new
      #r.user_id = @user.id
      #r.name = params[:filename]
      #r.save
      #save_s3(path,r)
      flash_message(:notice, "Recording saved.")
      redirect_to client_campaign_path(params[:campaign_id])
      return
    else
      @recording = @user.recordings.new
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

  def billing
    @breadcrumb="Billing"
    @account = @user.account || Account.new
    @oldcc = @account.cc
    if @account.last4.blank?
      @tempcc = ""
      @account.cc = ""
    else
      @tempcc = "xxxx xxxx xxxx #{@account.last4}"
      @account.cc = "xxxx xxxx xxxx #{@account.last4}"
    end

    if request.post?
      @account.user_id = @user.id
      @account.attributes = params[:account]

      if @account.cc==@tempcc
        @account.cc = @oldcc
      else
        if @account.cc.length > 4
          @account.last4 = @account.cc[@account.cc.length-4,4]
        else
          @account.last4 = @account.cc
        end
        @account.encyrpt_cc
      end

      name_arr=@account.name.split(" ")
      fname=name_arr.shift
      lname=name_arr.join(" ").strip

      # test an auth to make sure this card is good.
      creditcard = ActiveMerchant::Billing::CreditCard.new(
        :number     => @account.decrypt_cc,
        :month      => @account.expires_month,
        :year       => @account.expires_year,
        :type       => @account.cardtype,
        :first_name => fname,
        :last_name  => lname,
        :verification_value => params[:code]
      )

      if !creditcard.valid?
        if creditcard.expired?
          flash_now(:error, "The card expiration date you entered was invalid. Please try again.")
          @account.cc = ""
        else
          flash_now(:error, "The card number or security code you entered was invalid. Please try again.")
          @account.cc = ""
        end
        return
      end

      #      p = Payment.authorize(1, creditcard, {:ip=>getIP, :zip=>@account.zip, :billing_address => @account.address1})
      #      p.user_id = @user.id
      #      p.save
      #      if !p.success
      #        flash[:notice]="We had a problem authorizing that credit card.  Please try again"
      #        return
      #      end

      billing_address = {
          :name => "#{@user.fname} #{@user.lname}",
          :address1 => @account.address1 ,
          :zip =>@account.zip,
          :city     => @account.city,
          :state    => @account.state,
          :country  => 'US'
        }
      # billing_address = {
      #     :name     => "John Smith",
      #     :address1 => '123 First St.',
      #     :address2 => '',
      #     :city     => 'Los Angeles',
      #     :state    => 'CA',
      #     :country  => 'US',
      #     :zip      => '90068',
      #     :phone    => '310-555-1234'
      # }
      options = {:address => {}, :address1 => billing_address, :billing_address => billing_address, :ip=>"127.0.0.1", :order_id=>""}
      response = BILLING_GW.authorize(1, creditcard,options)
      logger.info response.inspect

      if response.success?
        flash_message(:notice, "Account activated.")
        @account.save
        @user.paid = 1
        @user.save
        redirect_to :action=>"index"
        return
      else
        flash_now(:error, "There was a problem validating your credit card.  Please email <a href='mailto:info@impactdialing.com'>info@impactdialing.com</a> for further support.")
      end

    end

  end

  def campaign_caller_id_verified
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
    @campaign.check_valid_caller_id_and_save
    ret=""
    if !@campaign.caller_id.blank? && !@campaign.caller_id_verified
      ret = "<div class='msg msg-error'> <p><strong>Your Campaign Caller ID is not verified.</strong></p> </div>"
    else
      ret = ""
    end
    render :text=>ret
  end

  def campaign_hash_delete
    #    cache_delete("avail_campaign_hash")
    ActiveRecord::Base.connection.execute("update caller_sessions set available_for_call=0")
    @campaign = Campaign.find_all_by_user_id_and_id(@user.id,params[:id])
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
    @voter = Voter.find_by_id_and_user_id(params[:id],@user.id)
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
    @voter = Voter.find_by_id_and_user_id(params[:id],@user.id) || Voter.new
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
        l = VoterList.find_by_name_and_user_id(params[:new_list_name], @user.id)
        if !l.blank?
          flash_now(:error, "List name cannot be blank")
          return
        end
      end
      if params[:voterList]=="0"
        list = VoterList.new
        list.campaign_id = @campaign.id
        list.name = params[:new_list_name]
        list.user_id = @user.id
        list.save
      else
        list = VoterList.find(params[:voterList])
      end

      @voter.voter_list_id = list.id
      @voter.user_id = @user.id
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
    @scripts = @user.scripts.active.manual.paginate :page => params[:page], :order => 'name'
  end

  def script_add
    if params[:id].blank?
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Add Script"]
    else
      @breadcrumb=[{"Scripts"=>"/client/scripts"},"Edit Script"]
    end
    @script = Script.find_by_id_and_user_id(params[:id],@user.id)
    @fields = ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"].concat(@script ? @script.user.custom_voter_fields.map(&:name) : [])
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

        @script.user_id = @user.id
        @script.save
        flash_message(:notice, "Script saved")
        redirect_to :action=>"scripts"
        return
      end
    end

  end

  def voter_view
    @campaign = Campaign.find_by_id_and_user_id(params[:campaign_id],@user.id)
    @breadcrumb=[{"Campaigns"=>client_campaigns_path},{@campaign.name => client_campaign_path(@campaign)},"View Voters"]
    #@voters = Voter.find_all_by_campaign_id_and_active_and_user_id(params[:campaign_id],1,@user.id)
    #    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id}", :order => 'LastName,FirstName,Phone'
    @voters = Voter.paginate :page => params[:page], :conditions =>"active=1 and campaign_id=#{@campaign.id} and voter_list_id in (#{@campaign.voter_lists.collect{|c| c.id.to_s + ","}}0)", :order => 'LastName,FirstName,Phone'
  end

  def reports
    if params[:id].blank?
      @breadcrumb = "Reports"
      @campaigns = @user.campaigns.manual
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
      @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
    render :layout=>false
    #    end
  end

  def report_usage
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
    if @campaign.blank?
      render :text=>"Unauthorized"
      return
    end

    set_report_date_range

    calls_util_sql="
    select sum(tDuration) as total_seconds,  sum(ceil(tDuration/60)) as total_mins
    from call_attempts ca
    where
    ca.campaign_id=#{params[:id]}
    and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
    and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "
    caller_util_sql="
    select sum(tDuration) as total_seconds,  sum(ceil(tDuration/60)) as total_mins
    from caller_sessions ca
    where
    ca.campaign_id=#{params[:id]}
    and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
    and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "
    @calls_util = ActiveRecord::Base.connection.execute(calls_util_sql)
    @caller_util = ActiveRecord::Base.connection.execute(caller_util_sql)

    calls_bill_sql="
    select sum(tDuration) as total_seconds,  sum(ceil(tDuration/60)) as total_mins
    from call_attempts ca
    where
    ca.campaign_id=#{params[:id]}
    and status <> 'Message delivered'
    and status <> 'Call abandoned'
    and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
    and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "

    vm_bill_sql="
    select sum(tDuration) as total_seconds,  sum(ceil(tDuration/60)) as total_mins
    from call_attempts ca
    where
    ca.campaign_id=#{params[:id]}
    and status = 'Message delivered'
    and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
    and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "

    abandon_bill_sql="
    select sum(tDuration) as total_seconds,  sum(ceil(tDuration/60)) as total_mins
    from call_attempts ca
    where
    ca.campaign_id=#{params[:id]}
    and status= 'Call abandoned'
    and created_at > '#{@from_date.strftime("%Y-%m-%d")}'
    and created_at < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "

    @calls_bill = ActiveRecord::Base.connection.execute(calls_bill_sql)
    @vm_bill = ActiveRecord::Base.connection.execute(vm_bill_sql)
    @abandon_bill = ActiveRecord::Base.connection.execute(abandon_bill_sql)



  end

  def report_overview
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @script = Script.find_by_id_and_user_id(params[:id],@user.id)
    if !@script.blank?
      @script.active=false
      @script.save
    end
    flash_message(:notice, "Script deleted")
    redirect_to :back
  end

  def report_caller
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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

    #{}find_all_by_user_id(@user.id)
    @responses = Voter.all(:select=>"distinct result", :conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'")
    @num_responses = Voter.all(:conditions=>"campaign_id = #{@campaign.id} and result is not null and result_date > '#{@from_date.strftime("%Y-%m-%d")}' and result_date < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'").length
  end

  def report_caller_overview
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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

    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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

      csv_string = FasterCSV.generate do |csv|
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
      @campaign=Campaign.find_by_id_and_user_id(params[:id].to_i,@user.id)
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
    @campaign = Campaign.find_by_id_and_user_id(params[:id],@user.id)
    if @campaign.nil?
      render :text=>"Campaign not found or access not permitted"
      return
    end
    render :layout=>false
  end

  def set_report_date_range
    begin
      if params[:from_date]
        @from_date=Date.parse params[:from_date]
        @to_date = Date.parse params[:to_date]
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

  def monitor
    @logged_in_campaigns = Campaign.all(:conditions=>"id in (select distinct campaign_id from caller_sessions where on_call=1 and user_id=#{@user.id})")
    #        @logged_in_callers = CallerSession.find_all_by_on_call(1)
    #        @ready_to_dial = CallAttempt.find_all_by_status("Call ready to dial", :conditions=>"call_end is null")
  end

  def eavesdrop_call
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    # a = t.call("POST", "Calls/#{caller.sid}", {'CurrentUrl'=>"#{appurl}/callin/callerEndCall?session=#{caller.id}"})
    session=CallerSession.find(params[:session_id])
    a = t.call("POST", "Calls", {'Timeout'=>"20", 'Caller' => session.campaign.caller_id, 'Called' => params[:num], 'Url'=>"#{APP_URL}/callin/monitorEavesdrop?session=#{session.id}&type=#{params[:type]}"})
    render :text=>""
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
      csv = FasterCSV.new(output, :row_sep => "\r\n")
      yield csv
    }
  end
end
