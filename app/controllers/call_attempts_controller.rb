class CallAttemptsController < ApplicationController
  def create
    call_attempt = CallAttempt.find(params[:id])
    robo_recording = RoboRecording.find(params[:robo_recording_id])
    call_response = CallResponse.log_response(call_attempt, robo_recording, params[:Digits])
    xml = call_attempt.next_recording(robo_recording, call_response)

    #TWILIO_LOG.info "#{call_attempt.voter.Phone} : DTMF input received : #{ params[:Digits] } for recording : #{robo_recording.name}"
    #TWILIO_LOG.info "Responding with : #{xml}"

    logger.info "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    logger.info "[dialer] DTMF input received. call_attempt: #{params[:id]} keypad: #{params[:Digits]} Response: #{xml}"
    render :xml => xml
  end

  def connect
    call_attempt = CallAttempt.find(params[:id])
    response = case params[:DialCallStatus] #using the 2010 api
                 when "answered-machine"
                   call_attempt.play_recorded_message
                 else
                   call_attempt.connect_to_caller(call_attempt.voter.caller_session)
               end
    render :xml => response
  end

  def disconnect
    call_attempt = CallAttempt.find(params[:id])
    render :xml => call_attempt.disconnect
  end

  def hangup
    call_attempt = CallAttempt.find(params[:id])
    call_attempt.end_running_call if call_attempt
    render :nothing => true
  end

  def end
    call_attempt = CallAttempt.find(params[:id])
    response = case params[:DialCallStatus] #using the 2010 api
                 when "hangup-machine"
                   call_attempt.voter.update_attributes(:status => CallAttempt::Status::HANGUP, :call_back => true)
                   call_attempt.update_attributes(:status => CallAttempt::Status::HANGUP, :call_end => Time.now)
                   call_attempt.hangup
                 when "no-answer"
                   call_attempt.voter.update_attributes(:status => CallAttempt::Status::NOANSWER, :call_back => true)
                   call_attempt.update_attributes(:status => CallAttempt::Status::NOANSWER, :call_end => Time.now)
                 when "busy"
                   call_attempt.voter.update_attributes(:status => CallAttempt::Status::BUSY, :call_back => true)
                   call_attempt.update_attributes(:status => CallAttempt::Status::BUSY, :call_end => Time.now)
                 when "fail"
                   call_attempt.voter.update_attributes(:status => CallAttempt::Status::FAILED, :call_back => true)
                   call_attempt.update_attributes(:status => CallAttempt::Status::FAILED, :call_end => Time.now)
                 else
                   call_attempt.hangup
               end
    render :xml => response
  end

  def update
    call_attempt = CallAttempt.find(params[:id])
    call_attempt.update_attributes(params[:call_attempt])
    call_attempt.update_attribute('status', CallAttempt::Status::SCHEDULED) if params[:call_attempt][:scheduled_date]
    render :text => 'Call Attempt updated', :status => :ok
  end

  def voter_response
    @call_attempt = CallAttempt.find(params[:id])
    @voter = Voter.find(params[:voter_id])
    params[:answers].each_value do |answer|
      voters_response = PossibleResponse.find(answer["value"])
      @voter.answers.create(:possible_response => voters_response, :question => voters_response.question)
    end
    voter = @call_attempt.campaign.all_voters.to_be_dialed.first
    Pusher[@call_attempt.caller_session.session_key].trigger("voter_push", voter ? voter.info : {})
    @call_attempt.caller_session.update_attribute(:voter_in_progress, nil)
    render :nothing => true
  end
end
