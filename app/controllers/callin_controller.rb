class CallinController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :set_vars, :preload_models
  after_filter :send_pusher

  def set_vars
    @say=false
    @play=false
    @gather=false
    @gathertimeout=15
    @redirect=false
    @hangup=false
    @pause=0
    @endpause=0
    @repeatRedirect=false
    @finishOnKey="#"
    @gatherPost=""
  end

  def send_pusher
    send_rt(@publish_channel,@publish_key,@publish_value) if !@publish_channel.blank?
  end


  def session_complete
    if(cookies[:session]==nil || cookies[:session]=="0") && params[:session].blank?
      logger.info "NO SESSION COOKIE"  
      @session=CallerSession.find_by_sid(params[:CallSid]) if !params[:CallSid].blank?
      @session=CallerSession.find_by_sid(params[:CallGuid]) if !params[:CallGuid].blank?
    else
      if !params[:session].blank?
        @session = CallerSession.find(params[:session])
      else
        @session = CallerSession.find(cookies[:session])
      end
    end
    if @session.nil?
      logger.info "BAILING ON SESSION_COMPLETE"  
      return 
    end
    #return if(cookies[:session]==nil || cookies[:session]=="0") && params[:session].blank?
    #remove this caller
    @session.endtime=Time.now
    @session.available_for_call=false
    @session.on_call=false
    @session.save
    logger.info "SESSION COOKIE #{@session.id} complete"
  end

  def index

    if !params[:test].blank? &&  params[:CallStatus]!="completed"
      #load test, campaign 38
      @campaign = Campaign.find(38)
      c = Caller.find(1)
      @session = CallerSession.new
      @session.caller_number = params[:Caller]
      @session.caller_id=c.id
      @session.campaign_id=@campaign.id
      @session.sid = params[:CallSid]
      @session.starttime=Time.now
      @session.available_for_call=true
      @session.on_call=true
      @session.save
      cookies[:session] = @session.id
      render :template => 'callin/start_conference.xml.builder', :layout => false
      return
    end

    if params[:CallStatus]=="completed"
      session_complete
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end

    # initial call-in
    att = params[:att] || 0
    if params[:att]=="3"
      #      @say="If you don't have a PIN, please ask your campaign manager for one and call back. Good-bye."
      @play="#{APP_URL}/wav/no_pin.wav"
      @hangup=true
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end

    @repeatRedirect="#{APP_URL}/callin?att=#{att.to_i+1}"
    @gatherPost = @repeatRedirect
    if params[:Digits].blank?
      # initial call-in
      #      @say="Welcome to Impact Dialing.  Please enter your pin."
      @play="#{APP_URL}/wav/welcome.wav"
      cookies[:session]=nil
    else
      # response with PIN
      c = Caller.find_by_pin_and_active(params[:Digits], true)
      if c.blank?
        #        @say="We could not find that pin, try again."
        @redirect="#{APP_URL}/callin/enter_group?session=0"
      else
        multi="ok"
        if !c.multi_user?
          logged_in = CallerSession.find_all_by_caller_id_and_on_call(c.id, true)
          if logged_in.length > 0
            multi="bad"
          end
          #check if user logged in already
          # avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
          # avail_campaign_hash.keys.each do |k|
          #   callerSessions = avail_campaign_hash[k]["callers"]
          #   callerSessions.each do |sess|
          #     if sess.caller_id==c.id
          #       multi="bad"
          #     end
          #   end
          # end
        end


        if multi=="ok"
          # redirect to group ID
          s = CallerSession.new
          s.caller_number = params[:Caller]
          s.caller_id=c.id
          s.sid = params[:CallSid]
          s.save
          @redirect="#{APP_URL}/callin/enter_group?session=#{s.id}"
        else
          #          @say="That PIN is already in use. Please enter another PIN."
          @play="#{APP_URL}/wav/pin_in_use.wav"
        end
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

    att = params[:att] || 0
    if params[:att]=="3"
      #      @say="If you don't have a campaign ID, please ask your campaign manager for one and call back. Good-bye."
      @play="#{APP_URL}/wav/no_pin.wav"
      @hangup=true
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end

    @repeatRedirect="#{APP_URL}/callin/enter_group?session=#{params[:session]}&att=#{att.to_i+1}"
    @gatherPost = @repeatRedirect
    if params[:session]!="0"
      @session = CallerSession.find(params[:session])
      cookies[:session] = @session.id
      @caller = @session.caller
    end

    if params[:Digits].blank?
      # initial call-in
      #      @say="Now enter your campaign ID"
      @play="#{APP_URL}/wav/enter_campaign_id.wav"
    else
      # response with PIN
      c = Campaign.find_by_group_id_and_active_and_user_id(params[:Digits], true, @caller.user_id) if params[:session]!="0"
      if params[:session]=="0" || c.blank?
        #        @say="We could not find that campain, try again."
        @play="#{APP_URL}/wav/invalid_credentials.wav"
        @gather=false
        @repeatRedirect="#{APP_URL}/callin"
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

    if @repeatRedirect!="#{APP_URL}/callin"
      @gather=true
      @numDigits=5
    end

    render :template => 'callin/index.xml.builder', :layout => false
  end

  def get_ready
    # params - session, campaign
    @finishOnKey=""
    @repeatRedirect="#{APP_URL}/callin/enter_group?session=#{params[:session]}&campaign=#{params[:campaign]}"
    @session = CallerSession.find(params[:session])
    if @session.sid.blank?
      @session.sid=params[:CallSid]
      @session.save
    end
    @caller = @session.caller
    @campaign = Campaign.find(params[:campaign])

    if @campaign.use_web_ui
      @gathertimeout=60
      if params[:CallStatus]=="completed"
        @publish_channel="#{@session.session_key}"
        @publish_key="hangup"
        @publish_value="ok"
        session_complete
        render :template => 'callin/index.xml.builder', :layout => false
        return
      else
        @publish_channel="#{@session.session_key}"
        @publish_key="confirm"
        @publish_value="go"
        cookies[:session] = @session.id
      end


      #      send_rt(@publish_channel,{@publish_key=>@publish_value})

    end

    if params[:Digits].blank?
      #      @say="Press star to begin taking calls, or press pound for instructions."
      @play="#{APP_URL}/wav/star_or_pound.wav"
    else

      if @campaign.use_web_ui
        @publish_channel="#{@session.session_key}"
        @publish_key="waiting"
        if @campaign.predective_type=="preview"
          @publish_value="preview"
        else
          @publish_value="ok"
        end
      end

      if params[:Digits]=="*"
        #send to conference room
        @session.starttime=Time.now
        @session.available_for_call=true
        @session.on_call=true
        @session.save

        #avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
        # if !avail_campaign_hash.has_key?(@campaign.id)
        #   avail_campaign_hash[@campaign.id] = {"callers"=>[@session], "calls"=>[]}
        # else
        #   if !avail_campaign_hash[@campaign.id]["callers"].index(@session)
        #     avail_campaign_hash[@campaign.id]["callers"] << @session
        #   end
        # end
        # cache_set("avail_campaign_hash") {avail_campaign_hash}
        render :template => 'callin/start_conference.xml.builder', :layout => false
        return
      elsif params[:Digits]=="#"
        #@say= "Impact Dialing eliminates unanswered phone calls, allowing you to spend your time talking to people instead of waiting for someone to pick up. When you're ready to start taking calls, press the star key. You'll hear a brief period of silence while Impact Dialing finds a someone who answers the phone. When you've been connected to someone, you'll hear this sound: bee-doop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up the phone. Instead, press star to end the call, and then enter the call result on your phone's keypad. Then press star to submit the result and keep taking calls, or press pound to submit the result and hang up. You will now be connected to the system. In a moment Impact Dialing will deliver you a call. Begin taking calls.  After a call: say Please enter your call result. Then press star to submit and keep taking calls, or press pound to submit and hang up."
        @play="#{APP_URL}/wav/instructions.wav"
        render :template => 'callin/start_conference.xml.builder', :layout => false
        return
      else
        #        @say="Press star to begin taking calls.  Press pound for instructions."
        @play="#{APP_URL}/wav/star_or_pound.wav"
      end
    end

    @gather=true
    @numDigits=1

    render :template => 'callin/index.xml.builder', :layout => false
  end

  def voterEndCall
    attempt = CallAttempt.find(params[:attempt])
    @hangup=true
    render :template => 'callin/index.xml.builder', :layout => false
  end

  def callerEndCall
    #session
    @hangup=true
    @publish_channel="#{params[:session]}"
    @publish_key="hangup"
    @publish_value="ok"
    session_complete

    render :template => 'callin/index.xml.builder', :layout => false
  end


  def pause_then_start_conference
    #when disposition aleady entered on web, pause then redirect here before
    # putting back in conference. a workaround for tilwio bug
    @session = CallerSession.find(params[:session])

    @campaign = @session.campaign
    render :template => 'callin/start_conference.xml.builder', :layout => false
    return
  end

  def leaveConf
    # reached after call ends
    #session #campaign

    if params[:campaign]=="38"
      #test campaign
      params[:Digits]="1"
    end

    @repeatRedirect="#{APP_URL}/callin/leaveConf?session=#{params[:session]}&campaign=#{params[:campaign]}"
    @session = CallerSession.find(params[:session])
    @caller = @session.caller
    @campaign = @session.campaign
   @script=@campaign.script

    #check for web response
    if @session.attempt_in_progress==nil
      #aleady entered result on web
#      render :template => 'callin/start_conference.xml.builder', :layout => false
      render :template => 'callin/pause_then_start_conference.xml.builder', :layout => false
      return
    end

    if params[:Digits].blank?
      #hangup on voter
      #not needed - endConferenceOnExit
      # attempt = CallAttempt.find_by_voter_id(@session.voter_in_progress, :order=>"id desc", :limit=>1)
      #       if attempt!=nil
      #         t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      #         a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
      #       end
      # initial call-in
      #      @play="#{APP_URL}/exitBeep.wav"
      if @session.session_key.blank?
         #get the first script question
         this_result_set = JSON.parse(eval("@script.result_set_#{@script.result_sets_used.first}" ))
         question_name=this_result_set["name"]
         if question_name.blank?
           @play="#{APP_URL}/wav/beep_enter_call_result.wav"
         else
           #this_result_set.keys.select{|k|  false && "Press #{k.gsub("keypad_","")} for #{this_result_set[k]}" if !this_result_set[k].blank?}
           choices=this_result_set.keys.select{|k|  this_result_set[k] && k!="name"}.collect{|k|  "Press #{k.gsub("keypad_","")} for #{this_result_set[k]}" }.join(".  ")
           @play="#{APP_URL}/wav/exitBeep.wav"
           @say="#{question_name}. Enter your response and then press star. #{choices}"
         end

      else
        # from web ui
        @play="#{APP_URL}/wav/webui_beep_enter_call_result.wav"
      end
      #      @say="Please enter your call result. Then press star to submit and keep taking calls."
      if @session.voter_in_progress!=nil
        #Voter.connection.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED") if @session.voter_in_progress.to_s=="16528"
        voter = Voter.find(@session.voter_in_progress)
        voter.status='Call finished'
        voter.result="No Disposition"
        #attempt = CallAttempt.find_by_voter_id(@session.voter_in_progress, :order=>"id desc", :limit=>1)
        attempt = CallAttempt.find(@session.attempt_in_progress)
        attempt.result="No Disposition"
        attempt.save
        voter.save
      end
    else
      # digits entered, response given
      @clean_digit = params[:Digits].gsub("#","").gsub("*","").slice(0..1)
      if params[:Digits]=="*"
        @say="Goodbye"
        @hangup=true
      elsif params[:Digits].chars.first=="0"
        @say="Invalid result.  Please try again."
      elsif JSON.parse(eval("@script.result_set_1" )).keys.index("keypad_#{@clean_digit}").nil? || JSON.parse(eval("@script.result_set_1" ))["keypad_#{@clean_digit}"].nil?
        #invalid choice
        @say="Invalid result.  Please try again."
      else
        attempt=@session.attempt_in_progress
        handle_multi_disposition_submit(@script.result_sets_used.first, attempt) #first element
        handle_disposition_submit

        if @script.result_sets_used.length>1
          redirect_to :action=>"next_question", :session=>@session.id, :num=>"1", :attempt=>attempt
          return
        end

        if @campaign.use_web_ui
          @publish_channel="#{@session.session_key}"
          @publish_key="waiting"
          if @campaign.predective_type=="preview"
            @publish_value="preview"
          else
            @publish_value="ok"
          end

        end


        render :template => 'callin/start_conference.xml.builder', :layout => false
        return
      end
    end

    @gather=true
    @numDigits=3
    @finishOnKey="*"

    render :template => 'callin/index.xml.builder', :layout => false
  end

  def next_question
    #session, #attempt
    @gather=true
    @numDigits=3
    @finishOnKey="*"
    @repeatRedirect="#{APP_URL}/callin/next_question?session=#{params[:session]}&num=#{params[:num]}&attempt=#{params[:attempt]}"
    @session = CallerSession.find(params[:session])
    @caller = @session.caller
    @campaign = @session.campaign
    @script=@campaign.script
    num=params[:num].to_i
    result_num=@script.result_sets_used[num]
    this_result_set = JSON.parse(eval("@script.result_set_#{result_num}" ))
    thisKeypadval= params[:Digits].gsub("#","").gsub("*","").slice(0..1) if !params[:Digits].blank?

    if params[:Digits].blank?
      question_name=this_result_set["name"]
      choices=this_result_set.keys.select{|k|  this_result_set[k] && k!="name"}.collect{|k|  "Press #{k.gsub("keypad_","")} for #{this_result_set[k]}" }.join(".  ")
 #     @say="#{question_name}.  #{choices}"
       @say="#{question_name}. Enter your response and then press star. #{choices}"
    elsif JSON.parse(eval("@script.result_set_#{result_num}" )).keys.index("keypad_#{thisKeypadval}").nil? || JSON.parse(eval("@script.result_set_#{result_num}" ))["keypad_#{thisKeypadval}"].nil?
       #invalid choice
       @say="Invalid result.  Please try again."
    else
      #record selection
      handle_multi_disposition_submit(result_num, params[:attempt])
      if @script.result_sets_used.length>num+1
        redirect_to :action=>"next_question", :session=>@session.id, :num=>num+1
        return
      end

      render :template => 'callin/start_conference.xml.builder', :layout => false
      return
    end

    render :template => 'callin/index.xml.builder', :layout => false
  end

  def start_conference
    # params - session, campaign
    @session = CallerSession.find(params[:session])
    @caller = @session.caller
    @campaign = Campaign.find(params[:campaign])
    render :template => 'callin/start_conference.xml.builder', :layout => false
  end

  # def voterleaveConf
  #    @hangup=true
  #    render :template => 'callin/index.xml.builder', :layout => false
  # end

  def voterFindSession
    # params session, voter, attempt
    # first callback for voters

    @campaign  = Campaign.find(params[:campaign])
    #Voter.connection.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED") if params[:voter]=="16528"
    @voter = Voter.find(params[:voter])
    #    attempt = CallAttempt.find_by_voter_id(params[:voter], :order=>"id desc", :limit=>1)
    @attempt = CallAttempt.find(params[:attempt])
    if @attempt.answertime==nil
      @attempt.answertime=Time.now
      @attempt.save
    end

    #logger.info "params[:DialStatus]: #{params[:DialStatus]}"
    if params[:DialStatus]=="answered-machine"
      # play the answering machine message
      logger.info "answered machine!"
      @play=@campaign.recording.file.url
      @hangup="true"
      @voter.status="Message delivered"
      @attempt.status="Message delivered"
      @voter.save
      @attempt.save
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end

    if params[:CallStatus]=="completed" || params[:CallStatus]=="no-answer" || params[:CallStatus]=="busy" || params[:CallStatus]=="failed" || params[:CallStatus]=="canceled"
      #clean up voter hangup

      # if params[:CallStatus]!="completed"
      #   t = Twilio.new(TWILIO_ACCOUNT,TWILIO_AUTH)
      #   a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
      #   attempt.call_end=Time.now
      #   attempt.save
      # end

       if params[:CallStatus]!="completed" && @campaign.use_web_ui && @campaign.predective_type=="preview"  && params[:selected_session]!=nil
          @session = CallerSession.find(params[:selected_session])
          send_rt(@session.session_key,'waiting','preview')
      end

      if params[:DialStatus]=="hangup-machine"
        @voter.status="Hangup or answering machine"
        @attempt.status="Hangup or answering machine"
        @voter.call_back=true
      elsif params[:DialStatus]=="no-answer"
        @voter.status="No answer"
        @attempt.status="No answer"
        @voter.call_back=true
      elsif params[:CallStatus]=="busy"
        @voter.status="No answer busy signal"
        @attempt.status="No answer busy signal"
        @voter.call_back=true
        # t = Twilio.new(TWILIO_ACCOUNT, TWILIO_AUTH)
        # a=t.call("POST", "Calls/#{attempt.sid}", {'CurrentUrl'=>"#{APP_URL}/callin/voterEndCall?attempt=#{attempt.id}"})
      elsif params[:CallStatus]=="canceled"
        @voter.status="Call cancelled"
        @attempt.status="Call cancelled"
        @voter.call_back=false
      elsif params[:CallStatus]=="failed"
        @voter.status="Call failed"
        @attempt.status="Call failed"
        @voter.call_back=false
      else
        if @attempt.caller_id==nil &&  @attempt.status!="Message delivered"
          #abandon
          #          @voter.status="Call completed with success."
          @attempt.status="Call abandoned"
        else
          @voter.status= CallAttempt::Status::SUCCESS unless (@voter.status== CallAttempt::Status::VOICEMAIL || @voter.status == CallAttempt::Status::SCHEDULED)
          @attempt.status= CallAttempt::Status::SUCCESS unless (@attempt.status== CallAttempt::Status::VOICEMAIL || @attempt.status == CallAttempt::Status::SCHEDULED)
        end
      end
      @attempt.call_end=Time.now
      @attempt.save
      @voter.save
      # if @campaign.predective_type=="preview" && params[:selected_session]
      #   send_rt(CallerSession.find(params[:selected_session]).session_key,{'waiting'=>'preview'})
      # end
      if @voter.caller_session_id!=nil
        @session = CallerSession.find(@voter.caller_session_id)
        if @session.endtime==nil
          #          @session.available_for_call=true
          @session.save
        end
      end
      # avail_campaign_hash = cache_get("avail_campaign_hash") {{}}
      # if avail_campaign_hash.has_key?(attempt.campaign_id)
      #   all_attempts = avail_campaign_hash[attempt.campaign_id]["calls"]
      #   n=0
      #   all_attempts.each do |mem_attempt|
      #     if mem_attempt.id == attempt.id
      #       avail_campaign_hash[attempt.campaign_id]["calls"].delete_at(n)
      #       cache_set("avail_campaign_hash") {avail_campaign_hash}
      #     end
      #     n+=1
      #   end
      # thisAttempt = avail_campaign_hash[attempt.campaign_id]["calls"].index(attempt)
      # if thisAttempt!=nil
      #   avail_campaign_hash[attempt.campaign_id]["calls"].delete_at(thisAttempt)
      #   cache_set("avail_campaign_hash") {avail_campaign_hash}
      # end
      #end
      render :template => 'callin/index.xml.builder', :layout => false
      return
    end


    if params[:selected_session].blank?
      @available_caller_session = CallerSession.find_by_campaign_id_and_available_for_call_and_on_call(@campaign.id, true, true, :order=>"rand()")
    else
      #preview dialing
      @available_caller_session = CallerSession.find_by_id_and_available_for_call_and_on_call(params[:selected_session], true, true, :order=>"rand()")
    end

    if @available_caller_session.blank?
      @anyCaller = CallerSession.find_by_campaign_id_and_on_call(@campaign.id, true)
      if @anyCaller==nil
        @hangup=true
      else
        @pause=2
        @redirect="#{APP_URL}/callin/voterFindSession?campaign=#{@campaign.id}&voter=#{@voter.id}&attempt=#{@attempt.id}"
      end
    else
      # ensure only one caller gets this voter
      begin

        CallerSession.transaction do
          raise "caller already in session" if CallerSession.find(@available_caller_session.id).available_for_call==false

          @available_caller_session.voter_in_progress = @voter.id
          @available_caller_session.attempt_in_progress = @attempt.id
          @available_caller_session.hold_time_start=nil
          @available_caller_session.available_for_call=false
          @available_caller_session.save
        end

        @attempt.caller_session_id=@available_caller_session.id
        @attempt.caller_id=@available_caller_session.caller.id
        @attempt.call_start=Time.now
        @attempt.caller_hold_time =(Time.now - @available_caller_session.hold_time_start).to_i if @available_caller_session.hold_time_start!=nil # end caller hold time
        @attempt.save

        @voter.status = "Connected to caller #{@available_caller_session.caller.pin} #{@available_caller_session.caller.email}"
        @voter.caller_session_id=@available_caller_session.id
        @voter.save

        if @campaign.use_web_ui
          script = @campaign.script
          @publish_channel="#{@available_caller_session.session_key}"
          family=[hash_from_voter_and_script(script,@attempt.voter)]
          @attempt.voter.families.each do |f|
          	family << hash_from_voter_and_script(script,f)
          end
          @publish_key="voter_start"
          publish_hash = {"attempt_id"=>@attempt.id, "family"=>family}
          if !script.voter_fields.nil?
            fields = JSON.parse(script.voter_fields)
            fields.each do |field|
              if @voter.has_attribute?(field)
                publish_hash[field] = @voter.get_attribute(field)
              else
                logger.info "FAMILY ERROR could not find #{field}  in #{@voter.id}"
              end
              #publish_hash[field] = eval("@voter.#{field}")
            end
          end
#          @publish_value=publish_hash.to_json
          @publish_value=publish_hash
        end
        render :template => 'callin/voter_start_conference.xml.builder', :layout => false
        return

      rescue Exception => e
        logger.debug "#{ e }(#{ e.class })! : #{e.backtrace}"
        logger.debug "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        # caller already connected to someone else
        @pause=2
        @available_caller_session.voter_in_progress = nil
        @available_caller_session.attempt_in_progress = nil
        @available_caller_session.available_for_call=true
        @available_caller_session.save
        @redirect="#{APP_URL}/callin/voterFindSession?campaign=#{@campaign.id}&voter=#{@voter.id}&attempt=#{@attempt.id}"
      end

    end

    render :template => 'callin/index.xml.builder', :layout => false
    return

  end

  def hash_from_voter_and_script(script,voter)
    publish_hash={:id=>voter.id, :classname=>voter.class.to_s}
#    publish_hash={:id=>voter.id}
    if !script.voter_fields.nil?
      fields = JSON.parse(script.voter_fields)
      fields.each do |field|
#        logger.info "field: #{field}"
        if voter.has_attribute?(field)
          publish_hash[field] = voter.get_attribute(field)
        else
          logger.info "FAMILY ERROR could not find #{field}  in #{voter.id}"
        end
      end
    end
    publish_hash
  end

  def hold
    render :template => 'callin/hold.xml.builder', :layout => false
    return
  end

  # def voterStart
  #   # params session, voter, attempt
  #   @session = CallerSession.find(params[:session])
  #   @session.available_for_call=false
  #   @session.save
  #   @caller = @session.caller
  #   @voter = Voter.find(params[:voter])
  #   @voter.status = "Connected to caller #{@caller.pin} #{@caller.email}"
  #   @voter.caller_session_id=@session.id
  #   @voter.save
  #   render :template => 'callin/voter_start_conference.xml.builder', :layout => false
  #   return
  # end

  def test
    # response.headers["Pragma"] = "no-cache"
    # response.headers["Cache-Control"] = "no-cache"
    # @play="#{APP_URL}/canta.mp3"
    # @hangup="true"
    # render :template => 'callin/index.xml.builder', :layout => false
    # return
    num = rand(100)
    if num < 10
      render :template => 'callin/reject.xml.builder', :layout => false
    elsif num < 90
      render :template => 'callin/pause.xml.builder', :layout => false
    else
      rnd = rand(100)
      if rnd < 70
        @play="#{APP_URL}/canta_short.mp3"
      else
        @play="#{APP_URL}/canta.mp3"
      end
#      @play2="#{APP_URL}/canta.mp3"
      @hangup="true"
      render :template => 'callin/index.xml.builder', :layout => false
    end
  end

  def monitorEavesdrop
    #types
    #0=eavesdrop
    #1=break in
    #2=take over

    if params[:type]=="0"
      @muted="true"
    else
      @muted="false"
    end
    render :template => 'callin/start_eavesdrop_conference.xml.builder', :layout => false
    return
  end

end
