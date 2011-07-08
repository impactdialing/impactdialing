class CallAttemptsController < ApplicationController
  def create
    call_attempt = CallAttempt.find(params[:id])
    robo_recording = RoboRecording.find(params[:robo_recording_id])
    call_response = CallResponse.log_response(call_attempt, robo_recording, params[:Digit])
    xml =
        if call_response.recording_response
          robo_recording.next ? robo_recording.next.twilio_xml(call_attempt) : robo_recording.hangup
        else
          call_response.times_attempted < 3 ?  robo_recording.twilio_xml(call_attempt) : robo_recording.hangup
        end



#    xml =
#        if recording_response
#
#          next_robo_recording = robo_recording.next
#          if next_robo_recording
#            next_robo_recording.twilio_xml(call_attempt)
#          else
#            Twilio::Verb.new { |v| v.hangup }.response
#          end
#        else
#          invalid_response = Twilio::Verb.new do |v|
#            v.say "You pressed something invalid. Hanging up."
#            v.hangup
#          end
#          invalid_response.response
#        end
    logger.info "[dialer] DTMF input received. call_attempt: #{params[:id]} keypad: #{params[:Digits]} Response: #{xml}"
    render :xml => xml
  end

  private
  def hangup

  end
end
