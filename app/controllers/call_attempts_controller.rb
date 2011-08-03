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

  def update
    call_attempt = CallAttempt.find(params[:id])
    call_attempt.update_attributes(params[:call_attempt])
    call_attempt.update_attribute('status', CallAttempt::Status::SCHEDULED) if params[:call_attempt][:scheduled_date]
    render :text => 'Call Attempt updated', :status => :ok
  end
end
