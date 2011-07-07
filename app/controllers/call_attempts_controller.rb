class CallAttemptsController < ApplicationController
  def create
    robo_recording = RoboRecording.find(params[:robo_recording_id])
    recording_response = robo_recording.response_for(params[:Digits])
    call_attempt = CallAttempt.find(params[:id])
    xml =
        if recording_response
          call_attempt.call_responses.create!(:response => params[:Digits], :recording_response => recording_response)
          next_robo_recording = robo_recording.next
          if next_robo_recording
            next_robo_recording.twilio_xml(call_attempt)
          else
            Twilio::Verb.new { |v| v.hangup }.response
          end
        else
          invalid_response = Twilio::Verb.new do |v|
            v.say "You pressed something invalid. Hanging up."
            v.hangup
          end
          invalid_response.response
        end
    logger.info "[dialer] DTMF input received. call_attempt: #{params[:id]} keypad: #{params[:Digits]} Response: #{xml}"
    render :xml => xml
  end
end
