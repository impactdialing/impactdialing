class CallerController < ApplicationController
  layout "caller"
  before_filter :check_login, :except=>[:login, :feedback, :assign_campaign]
  before_filter :redirect_to_ssl
  before_filter :connect_to_twilio, :only => [:preview_dial]

  def index
    @campaigns = @caller.campaigns.active.collect{|c| c if c.use_web_ui? }
  end


  def check_login
    if session[:caller].blank?
      redirect_to caller_login_path
      return
    end
    begin
      @caller = Caller.find(session[:caller])
    rescue
      logout
    end
  end

  def logout
    session[:caller]=nil
    redirect_to :controller => 'caller', :action=>"index"
  end

  def login
    @breadcrumb="Login"
    @title="Login to Impact Dialing"

    if !params[:email].blank?
      @caller = Caller.find_by_email_and_password(params[:email], params[:password])
      if @caller.blank?
        flash_now(:error, "Invalid Login")
      else
        session[:caller]=@caller.id
        redirect_to :action=>"index"
      end
    end
  end

  def assign_campaign
    @session = CallerSession.find(params[:session])
    @campaign = @session.caller.user.campaigns.find_by_campaign_id(params[:Digits])
    if @campaign
      @session.update_attributes(:campaign => @campaign)
      render :xml => @session.start
    else
      render :xml => @session.ask_for_campaign(params[:attempt])
    end
  end

  def campaign
    require "hpricot"
    require "open-uri"

    @campaign = Campaign.find_by_id(params[:id])
    @script=@campaign.script
    @client_ip = request.remote_ip

    if !@caller.campaigns.index(@campaign)
      redirect_to :action=>"index"
      return
    else
      @breadcrumb=@campaign.name
    end

    @session = CallerSession.find_by_session_key(params[:key]) if !params[:key].blank? #use for debug
    @on_call = CallerSession.find_by_caller_id_and_on_call_and_campaign_id(@caller.id, true, @campaign.id)
    @key = @on_call.session_key if @on_call!=nil
    @session = @on_call if @on_call!=nil

    if request.post?
      if !phone_number_valid(params[:numtocall]) && !params[:numtocall].blank? && params[:client]=="0"
        flash_now(:error, "Please enter a valid phone number")
      else
        @session = CallerSession.new
        @session.caller_number = phone_format(params[:numtocall])
        @session.caller_id=@caller.id
        @session.campaign_id=@campaign.id
        @session.session_key=generate_session_key
        @session.save

        if params[:client]=="0"
          t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
          a=t.call("POST", "Calls", {'Caller' => APP_NUMBER, 'Called' => params[:numtocall], 'Url'=>"#{APP_URL}/callin/get_ready?campaign=#{params[:id]}&session=#{@session.id}"})
          @doc = Hpricot::XML(a)
          @session.sid=(@doc/"Sid").inner_html
          @session.save
        else
          twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
          twilio_capability.allow_client_outgoing(TWILIO_APP_SID)
          @token = twilio_capability.generate
          @params="{'campaign':'#{params[:id]}', 'session':'#{@session.id}', 'Digits':'*'}"
          @session.caller_number="client"
          @session.save
        end
      end
    end

  end

  def jspush
    response.headers["Content-Type"] = 'text/javascript'
    @start_action_div_contents = '
    Enter your phone number:
    		<input type="text" name="numtocall" id="numtocall" placeholder="Type your phone number here">
    		<p>
    			<div class="buttons">
    				<button type="submit">Start taking calls</button>
    			</div>

    			<p><input type="radio" name="client" value="0" checked onclick="$(\'#numtocall\').show();"> Call my Phone</p>
    			<p><input type="radio" name="client" value="1" onclick="$(\'#numtocall\').hide(\'slide\', { direction: \'up\' }, 400);"> Use Browser Phone</p>

    		</p>
    '
    @session = CallerSession.find_by_session_key(params[:id])
    @on_call = CallerSession.find_by_session_key_and_on_call(params[:id], true)
    @campaign=@session.campaign
    respond_to do |format|
      format.js
    end
  end

  def session_ready
    require 'net/http'
    require 'net/https'
    require 'uri'

    session = CallerSession.find_by_session_key(params[:id])
    session.starttime=Time.now
    session.available_for_call=true
    session.on_call=true
    session.save

    #redirect to start
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/start_conference?session=#{session.id}&campaign=#{session.campaign_id}"})

    #update rt
    if Campaign.find(session.campaign_id).predictive_type=="preview"
      send_rt(params[:id], 'waiting', 'preview')
    else
      send_rt(params[:id], 'waiting', 'ok')
    end
    render :text=> "var x='ok';"
  end


  def session_end
    require 'net/http'
    require 'net/https'
    require 'uri'

    logger.info "SESSION END CALLED"

    if params[:key]
      session = CallerSession.find_by_session_key(params[:key])
    else
      session = CallerSession.find_by_session_key(params[:id])
    end

    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/callerEndCall?session=#{session.id}"})

    #client new

    if session.caller_number=="client"
      session.endtime=Time.now
      session.available_for_call=false
      session.on_call=false
      session.save

      send_rt(session.session_key, 'hangup', 'ok')
    end

    #update rt
    #send_rt(params[:id],'hangup','ok') #this done in callerEndCall
    render :text=> "var x='ok';"
    return
  end

  def drop_call
    @session = CallerSession.find_by_session_key(params[:key])
    return if @session.blank?
    attempt = CallAttempt.find(params[:attempt])
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
    render :text=> "var x='ok';"
  end

  def submit_result
    #@session @clean_digit @caller @campaign
    @session = CallerSession.find_by_session_key(params[:key])
    return if @session.blank?
    @campaign = @session.campaign
    @script = @campaign.script
    @clean_digit=nil
    @clean_response=nil
    @clean_incomplete=nil
    if @script.incompletes!=nil && @script.incompletes.index("{")
      incompletes=JSON.parse(@script.incompletes)
    else
      incompletes={}
    end

    #new style results
    result_json={}
    @script.result_sets_used.each do |r|
      this_result_set = JSON.parse(eval("@script.result_set_#{r}"))
      thisKeypadval=eval("params[:disposition#{r}]")
      this_result_text=this_result_set["keypad_#{thisKeypadval}"]
      result_json["result_#{r}"]=[this_result_text, thisKeypadval]
      @clean_digit=thisKeypadval if @clean_digit.blank?
      @clean_response=this_result_text if @clean_response==nil
#      logger.info "!!!@clean_response=#{@clean_response}!!!"
      this_incomplete = incompletes[r.to_s] || []

      if this_incomplete.index(thisKeypadval.to_s)
        @clean_incomplete=true
      else
        @clean_incomplete=false
      end
    end
    @script.notes_used.each do |r|
      thisResult=eval("params[:note#{r}]")
      result_json["note_#{r}"]=[thisResult]
    end
    if @session.voter_in_progress!=nil
      voter = Voter.find(@session.voter_in_progress)
      voter.result_json=result_json
      voter.save
    end
    attempt = CallAttempt.find(@session.attempt_in_progress)
    attempt.result_json=result_json
    attempt.save

    #@clean_digit=params[:disposition]

    @family_submitted=params[:family]
    @caller = @session.caller
    attempt = CallAttempt.find(params[:attempt])
    t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
    handle_disposition_submit

    #update rt
    if params[:hangup]=="1"
      session_end
    else
      t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      a=t.call("POST", "Calls/#{@session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/start_conference?session=#{@session.id}&campaign=#{@campaign.id}"})

      if @campaign.predictive_type=="preview"
        send_rt(params[:key], 'waiting', 'preview')
      else
        send_rt(params[:key], 'waiting', 'ok')
      end

      render :text=> "var x='ok';"
    end
  end

  def js
    response.headers["Content-Type"] = 'text/javascript'

    @session = CallerSession.find_by_session_key(params[:id])
    @campaign=@session.campaign
    respond_to do |format|
      format.js
    end
  end

  def preview_choose
    @session = CallerSession.find_by_session_key(params[:key])
    @campaign = @session.campaign
    @voters = @campaign.voters("not called", true, 25)
    render :layout=>false
  end

  def reconnect_rt
    send_rt(params[:key], params[:k], params[:v])
    render :text=> "var x='ok';"
  end

  def preview_dial
    @session = CallerSession.find_by_session_key(params[:key])
    @campaign = @session.campaign
    @voter = Voter.find_by_campaign_id_and_id(@campaign.id, params[:voter_id])
    @session.call(@voter)
    send_rt(params[:key], 'waiting', 'preview_dialing')
    render :text=> "var x='ok';"
  end

  def connect_to_twilio
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  end

  def dpoll
    response.headers["Content-Type"] = 'text/javascript'

    @on_call = CallerSession.find_by_session_key(params[:key])
    if (@on_call==nil || @on_call.on_call==false)
      #hungup?  the view will reload the page in this case to reset the ui
    else
      @campaign = @on_call.campaign
    end
    respond_to do |format|
      format.js
    end
  end

  def feedback
    Postoffice.feedback(params[:issue]).deliver
    render :text=> "var x='ok';"
  end
end
