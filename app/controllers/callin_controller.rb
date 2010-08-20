class CallinController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :set_vars, :preload_models

  def set_vars
    @say=false
    @play=false
    @gather=false
    @redirect=false
    @hangup=false
    @finishOnKey="#"
    @pause=0
    @repeatRedirect=false
  end


  def index
    
    if params[:CallStatus]=="completed"
      #remove this caller
      @session = CallerSession.find(cookies[:session])
      @session.endtime=Time.now
      @session.available_for_call=false
      @session.save
      avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
      if avail_campaign_hash.has_key?(@session.campaign_id)
        thisSession = avail_campaign_hash[@session.campaign_id]["callers"].index(@session)
        if thisSession!=nil
          avail_campaign_hash[@session.campaign_id]["callers"].delete_at(thisSession)
          cache_set("avail_campaign_hash") {avail_campaign_hash}
        end
      end
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end

    cookies[:session]=nil
    
    # initial call-in
    @repeatRedirect="#{APP_URL}/callin"
    if params[:Digits].blank?
      # initial call-in
      @say="Welcome.  Please enter your Pin now."
    else
      # response with PIN
      c = Caller.find_by_pin_and_active(params[:Digits], true)
      if c.blank?
        @say="We could not find that pin, try again."
      else
        # redirect to group ID
        s = CallerSession.new
        s.caller_id=c.id
        s.save
        @redirect="#{APP_URL}/callin/enter_group?session=#{s.id}"
      end
    end

    @gather=true
    @numDigits=5

    render :template => 'callin/index.xml.builder', :layout => false

    #"CallStatus"=>"in-progress",
    #"CallStatus"=>"completed"
  end
  
  def enter_group
    # params - session
    @repeatRedirect="#{APP_URL}/callin/enter_group?session=#{params[:session]}"
    @session = CallerSession.find(params[:session]) 
    cookies[:session] = @session.id
    @caller = @session.caller

    if params[:Digits].blank?
      # initial call-in
      @say="Now enter your campaign ID"
    else
      # response with PIN
      c = Campaign.find_by_group_id_and_active_and_user_id(params[:Digits], true, @caller.user_id)
      if c.blank?
        @say="We could not find that campain, try again."
      elsif c.callers.index(@caller)==nil
        @say="You do not have access to this campaign.  Goodbye."
        @hangup=true
      else
        # redirect to group ID
        @session.campaign_id=c.id
        @session.save
        @redirect="#{APP_URL}/callin/get_ready?session=#{@session.id}&campaign=#{c.id}"
      end
    end

    @gather=true
    @numDigits=5

    render :template => 'callin/index.xml.builder', :layout => false
  end

  
  def get_ready
    # params - session, campaign
    @repeatRedirect="#{APP_URL}/callin/enter_group?session=#{params[:session]}&campaign=#{params[:campaign]}"
    @session = CallerSession.find(params[:session]) 
    @caller = @session.caller
    @campaign = Campaign.find(params[:campaign])

    if params[:Digits].blank?
      @say="Press star to begin taking calls.  Press pound for instructions."
    else
      if params[:Digits]=="*"
        #send to conference room
        @session.starttime=Time.now
        @session.available_for_call=true
        @session.save
        avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
#        avail_callers_hash = cache_get("avail_callers_hash") {{}}
        #if !avail_callers_hash.has_key?(@session.id)
        if !avail_campaign_hash.has_key?(@campaign.id)
          avail_campaign_hash[@campaign.id] = {"callers"=>[@session], "calls"=>[]}
#          avail_callers_hash[@session.id] = @session
#          cache_set("avail_callers_hash") {avail_callers_hash}
        else
          if !avail_campaign_hash[@campaign.id]["callers"].index(@session)
            avail_campaign_hash[@campaign.id]["callers"] << @session
          end
        end
        cache_set("avail_campaign_hash") {avail_campaign_hash}
        render :template => 'callin/start_conference.xml.builder', :layout => false
        return
      elsif params[:Digits]=="#"
        @say="Help Text here. Press star to begin taking calls.  Press pound for instructions."
      else
        @say="Press star to begin taking calls.  Press pound for instructions."
      end
    end

    @gather=true
    @finishOnKey=""
    @numDigits=1

    render :template => 'callin/index.xml.builder', :layout => false
  end
    
  def voterEndCall
    attempt = CallAttempt.find(params[:attempt])
    @hangup=true
    render :template => 'callin/index.xml.builder', :layout => false
  end
  
  def leaveConf
    # reached after call ends
    @session = CallerSession.find(params[:session]) 
    @caller = @session.caller
    @campaign = @session.campaign


    if params[:Digits].blank?
      #hangup on voter
      attempt = CallAttempt.find_by_voter_id(@session.voter_in_progress, :order=>"id desc", :limit=>1)
      if attempt!=nil
        t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
        a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
      end
      # initial call-in
      @say="Input your result code or star to hangup"
    else

      # response with PIN
      if params[:Digits]=="*"
        @say="Goodbye"
        @hangup=true
      else
        @say="Thank you."
        results = VoterResult.new
        results.caller_id=@caller.id
        results.voter_id=@session.voter_in_progress
        results.campaign_id=@campaign.id
        results.status=params[:Digits]
        results.save
        voter = Voter.find(@session.voter_in_progress)
        voter.status='Call finished'
        if @campaign.script!=nil
          voter.result=eval("@campaign.script.keypad_" + params[:Digits])
        end
        voter.save
        @session.available_for_call=true
        @session.voter_in_progress=nil
        @session.save
        
        #send to conference room
        render :template => 'callin/start_conference.xml.builder', :layout => false
        return
      end
    end

    @gather=true
    @numDigits=1

    render :template => 'callin/index.xml.builder', :layout => false
  end
  
  def voterleaveConf
     @hangup=true
     render :template => 'callin/index.xml.builder', :layout => false
  end
  
  def voterFindSession
    # params session, voter
    # first callback for voters

    @campaign  = Campaign.find(params[:campaign])
    @voter = Voter.find(params[:voter])
    attempt = CallAttempt.find_by_voter_id(params[:voter], :order=>"id desc", :limit=>1)

    if params[:CallStatus]=="completed" || params[:CallStatus]=="no-answer"

      if params[:DialStatus]=="hangup-machine"
        @voter.status="Hangup or answering machine"
        attempt.status="Hangup or answering machine"
      elsif params[:DialStatus]=="no-answer"
        @voter.status="No answer"
        attempt.status="No answer"
      else
        @voter.status="Call completed with success."
        attempt.status="Call completed with success."
      end
      attempt.call_end=Time.now
      attempt.save
      @voter.save
      #clear old sessions
      @sessions = CallerSession.find_all_by_voter_in_progress_and_campaign_id(@voter.id, @campaign.id)
      @sessions.each do |session|
        session.available_for_call=false
        session.save
      end

      @session = CallerSession.find_by_voter_in_progress_and_campaign_id(@voter.id, @campaign.id, :order=>"id desc")
      if @session!=nil
        @session.available_for_call=true
        @session.save
      end
      avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
      if avail_campaign_hash.has_key?(attempt.campaign_id)
        thisAttempt = avail_campaign_hash[attempt.campaign_id]["calls"].index(attempt)
        if thisAttempt!=nil
          avail_campaign_hash[attempt.campaign_id]["calls"].delete_at(thisAttempt)
          cache_set("avail_campaign_hash") {avail_campaign_hash}
        end
      end
    end

#    @session = CallerSession.find(params[:session]) 
#    @caller = @session.caller
#    @campaign = @session.campaign
    
    @availableCaller = CallerSession.find_by_campaign_id_and_available_for_call(@campaign.id, true)
    if @availableCaller.blank?
      @pause=2
      @redirect="#{APP_URL}/callin/voterFindSession?campaign=#{@campaign.id}&voter=#{@voter.id}"
    else
      @availableCaller.voter_in_progress = @voter.id
      @availableCaller.save
      attempt.caller_session_id=@availableCaller.id
      attempt.caller_id=@availableCaller.caller.id
      attempt.call_start=Time.now
      attempt.save
      @redirect="#{APP_URL}/callin/voterStart?session=#{@availableCaller.id}&voter=#{@voter.id}"
    end

    render :template => 'callin/index.xml.builder', :layout => false
    return
      
  end

  def voterStart
    # params session, voter
    @session = CallerSession.find(params[:session]) 
    @session.available_for_call=false
    @session.save
    @caller = @session.caller
    @campaign = @session.campaign
    @voter = Voter.find(params[:voter])
    @voter.status = "Connected to caller #{@caller.pin} #{@caller.email}"
    render :template => 'callin/voter_start_conference.xml.builder', :layout => false
    return
  end

end
