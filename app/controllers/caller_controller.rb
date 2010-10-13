class CallerController < ApplicationController
  layout "caller"
  before_filter :check_login, :except=>[:login]

  def index
    if request.post?
      if params[:campaign_id].blank?
        flash.now[:error]= "Please select a campaign"
      else
        redirect_to :action=>"campaign", :id=>params[:campaign_id]
        return
      end
    end
  end


  def check_login
    if session[:caller].blank?
      redirect_to :action=>"login"
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
      @caller = Caller.find_by_email_and_password(params[:email],params[:password])
      if @caller.blank?
        flash.now[:error]="Invalid Login"
      else
        session[:caller]=@caller.id
        redirect_to :action=>"index"
      end
    end

  end

  def campaign
    require "hpricot"
    require "open-uri"

    @campaign = Campaign.find_by_id(params[:id])
    @script=@campaign.script
    if !@caller.campaigns.index(@campaign)
      redirect_to :action=>"index"
      return
    else
      @breadcrumb=@campaign.name
    end
    @session = CallerSession.find_by_session_key(params[:key]) if !params[:key].blank? #use for debug

    if request.post?
      if !phone_number_valid(params[:numtocall])
        flash.now[:error]= "Please enter a valid phone number"
      else

        @session = CallerSession.new
        @session.caller_number = phone_format(params[:numtocall])
        @session.caller_id=@caller.id
        @session.campaign_id=@campaign.id
        @session.session_key=generate_session_key
        @session.save


        #flash[:notice]= "Calling you now"
        t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
        a=t.call("POST", "Calls", {'Caller' => APP_NUMBER, 'Called' => params[:numtocall], 'Url'=>"#{APP_URL}/callin/get_ready?campaign=#{params[:id]}&session=#{@session.id}"})
        @doc = Hpricot::XML(a)
        @session.sid=(@doc/"Sid").inner_html
        @session.save
        #        redirect_to :action=>"campaign", :id=>params[:id], :key=>s.session_key
        #        return

      end
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
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/start_conference?session=#{session.id}&campaign=#{session.campaign_id}"})

    #update rt
    send_rt (params[:id],{'waiting'=>'ok'})
    render :text=>  "ok"
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

    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/callerEndCall?session=#{session.id}"})

    #update rt
    send_rt (params[:id],{'hangup'=>'ok'})
    render :text=>  "ok hangup #{session.sid}"
    return
  end
  
  def drop_call
    @session = CallerSession.find_by_session_key(params[:key])
    return if @session.blank?
    attempt = CallAttempt.find(params[:attempt])
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
    render :text=>"drop ok"
  end


  def submit_result

    #@session @clean_digit @caller @campaign
    @session = CallerSession.find_by_session_key(params[:key])
    return if @session.blank?
    @clean_digit=params[:disposition]
    @caller = @session.caller
    @campaign = @session.campaign

    attempt = CallAttempt.find(params[:attempt])
    t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})

    handle_disposition_submit


    #update rt
    if params[:hangup]=="1"
      session_end
    else
      t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      a=t.call("POST", "Calls/#{@session.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/start_conference?session=#{@session.id}&campaign=#{@campaign.id}"})

      send_rt (params[:key],{'waiting'=>'ok'})
      render :text=>  "ok"
    end

  end
  
  def js
    response.headers["Content-Type"] = 'text/javascript'
    
    @session = CallerSession.find_by_session_key(params[:id])
    respond_to do |format|
        format.js
    end
#    render
  end

end
