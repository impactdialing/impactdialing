class RoboController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :set_vars

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
    @redirsay=""
  end
  
  def status_callback
    @retval=false
    @campaign  = Campaign.find(params[:campaign])
    @voter = Voter.find(params[:voter])
    attempt = CallAttempt.find(params[:attempt])
    if attempt.answertime==nil
      attempt.answertime=Time.now
      attempt.save
    end

    if params[:CallStatus]=="completed" || params[:CallStatus]=="no-answer" || params[:CallStatus]=="busy" || params[:CallStatus]=="failed" || params[:CallStatus]=="canceled"
      @retval=true
      if params[:DialStatus]=="hangup-machine"
        @voter.status="Hangup or answering machine"
        attempt.status="Hangup or answering machine"
        @voter.call_back=true
      elsif params[:DialStatus]=="no-answer"
        @voter.status="No answer"
        attempt.status="No answer"
        @voter.call_back=true
      elsif params[:CallStatus]=="busy"
        @voter.status="No answer busy signal"
        attempt.status="No answer busy signal"
        @voter.call_back=true
      elsif params[:CallStatus]=="canceled"
        @voter.status="Call cancelled"
        attempt.status="Call cancelled"
        @voter.call_back=false
      elsif params[:CallStatus]=="failed"
        @voter.status="Call failed"
        attempt.status="Call failed"
        @voter.call_back=false
      else
        attempt.status="Call completed with success."
        @voter.status="Call completed with success."
      end
      attempt.call_end=Time.now
      attempt.save
      @voter.save
      if @voter.caller_session_id!=nil
        @session = CallerSession.find(@voter.caller_session_id)
        if @session.endtime==nil
          @session.save
        end
      end
      @retval
    end

    if @retval==false
      @availableCaller = CallerSession.find_by_campaign_id(@campaign.id)
      @availableCaller.voter_in_progress = @voter.id
      @availableCaller.attempt_in_progress = attempt.id
      @availableCaller.save
      attempt.caller_session_id=@availableCaller.id
      attempt.caller_id=@availableCaller.caller.id
      attempt.call_start=Time.now
      attempt.save
      @attempt=attempt
      @session = @availableCaller
      @session.available_for_call=false
      @attempt.caller_hold_time = (Time.now - @session.hold_time_start).to_i if @session.hold_time_start!=nil
      @attempt.save
      @session.hold_time_start=nil
      @session.save
      @caller = @session.caller
      @voter.status = "Connected to caller #{@caller.pin} #{@caller.email}"
      @voter.caller_session_id=@session.id
      @voter.attempt_id=@attempt.id
      @voter.save
    end

  end

  def treatment
    status_callback
    if @retval==true
      render :template => 'robo/index.xml.builder', :layout => false
      return
    end
    @numDigits="1"
    if !params[:Digits].blank?
      if params[:Digits]=="2"
        @play="/robo/Part2-NO.mp3"
      elsif params[:Digits]=="1"
        @play="/robo/Part2-YES.mp3"
        @gather=true
        @gatherPost="/robo/treatment_record?t=#{params[:t]}&campaign=#{params[:campaign]}&voter=#{params[:voter]}&attempt=#{params[:attempt]}"
      else
        @say="We did not receive your response"
        @gather=true
        @play="/robo/Part1-HolmesTREAT.mp3"
      end
    else
      @gather=true
      if params[:t]=="1"
        @play="/robo/Part1-HolmesTREAT.mp3"
      else
        @play="/robo/Part1-PetersCONTROL.mp3"
      end
    end
    render :template => 'robo/index.xml.builder', :layout => false
    return
  end
  
  def treatment2
    status_callback
    if @retval==true
      render :template => 'robo/index.xml.builder', :layout => false
      return
    end
    @numDigits="1"
    if !params[:Digits].blank?
      if params[:Digits]=="2"
        @play="/robo/newPart2-NO.mp3"
        attempt = CallAttempt.find(params[:attempt])
        attempt.result_digit="0"
        attempt.save
        voter = Voter.find(attempt.voter_id)
        voter.result_digit="0"
        voter.result_date=Time.now
        voter.call_back=false
        voter.save
      elsif params[:Digits]=="1"
        @play="/robo/newPart2-YES.mp3"
        @gather=true
        @gatherPost="/robo/treatment_record2?t=#{params[:t]}&campaign=#{params[:campaign]}&voter=#{params[:voter]}&attempt=#{params[:attempt]}"
      else
        @say="We did not receive your response"
        @gather=true
        @play="/robo/#{params[:t]}.mp3"
      end
    else
      @gather=true
      @play="/robo/#{params[:t]}.mp3"
    end
    render :template => 'robo/index.xml.builder', :layout => false
    return
  end


  def treatment_record2
    #record response
    if params[:Digits]!="1" && params[:Digits]!="2" && params[:Digits]!="3"
      @redirsay="Your response was invalid"
      @repeatRedirect="/robo/treatment2?t=#{params[:t]}&campaign=#{params[:campaign]}&voter=#{params[:voter]}&attempt=#{params[:attempt]}&Digits=1"
    else
      attempt = CallAttempt.find(params[:attempt])
      attempt.result_digit=params[:Digits]
      attempt.save
      voter = Voter.find(attempt.voter_id)
      voter.result_digit=params[:Digits]
      voter.call_back=false
      voter.result_date=Time.now
      voter.save
      @play="/robo/newPart3-YES.mp3"
    end
    render :template => 'robo/index.xml.builder', :layout => false
    return
  end

  def treatment_record
    #record response
    if params[:Digits]!="1" && params[:Digits]!="2" && params[:Digits]!="3"
      @redirsay="Your response was invalid"
      @repeatRedirect="/robo/treatment?t=#{params[:t]}&campaign=#{params[:campaign]}&voter=#{params[:voter]}&attempt=#{params[:attempt]}&Digits=1"
    else
      attempt = CallAttempt.find(params[:attempt])
      attempt.result_digit=params[:Digits]
      attempt.save
      voter = Voter.find(attempt.voter_id)
      voter.result_digit=params[:Digits]
      voter.result_date=Time.now
      voter.call_back=false
      voter.save
      @play="/robo/Part3-YES.mp3"
    end
    render :template => 'robo/index.xml.builder', :layout => false
    return
  end

end
