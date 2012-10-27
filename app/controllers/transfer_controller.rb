require Rails.root.join("lib/twilio_lib")
class TransferController < ApplicationController
  
  def connect
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attribute(:connecttime, Time.now)
    if transfer_attempt.call_attempt.status == CallAttempt::Status::SUCCESS
      render xml: transfer_attempt.hangup
      return
    end
    transfer_attempt.redirect_callee
    if transfer_attempt.transfer_type == Transfer::Type::WARM
      transfer_attempt.redirect_caller
      transfer_attempt.caller_session.publish("warm_transfer",{})
    else
      conference_sid = transfer_attempt.caller_session.get_conference_id
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Conference.kick_participant(conference_sid, transfer_attempt.caller_session.sid)
    end
    transfer_attempt.caller_session.publish('transfer_connected', {type: transfer_attempt.transfer_type})
    render xml: transfer_attempt.conference        
  end
  
  def disconnect
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attributes(:status => CallAttempt::Status::SUCCESS)
    if transfer_attempt.caller_session.attempt_in_progress != nil && transfer_attempt.caller_session.attempt_in_progress.id == transfer_attempt.call_attempt.id
      transfer_attempt.caller_session.publish('transfer_conference_ended', {})
    end
    
    render xml: Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end
  
  def end
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]], :call_end => Time.now)
    response = case params[:CallStatus] #using the 2010 api
                 when "no-answer", "busy", "failed"
                  transfer_attempt.caller_session.publish('transfer_busy', {})
                   transfer_attempt.fail
                 else
                   transfer_attempt.hangup
               end
    render :xml => response    
  end
  
  def dial
    transfer = Transfer.find(params[:transfer][:id])
    caller_session = CallerSession.find(params[:caller_session])    
    call = Call.find(params[:call])
    voter = Voter.find(params[:voter])
    transfer.dial(caller_session, call.call_attempt, voter, transfer.transfer_type)    
    render json: {type: transfer.transfer_type}
  end
  
  
  def callee
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => true, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end
    end.response
    render xml: response    
  end
  
  def caller
    
    caller_session = CallerSession.find(params[:caller_session])
    caller = Caller.find(caller_session.caller_id)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, action: pause_caller_url(caller, session_id:  caller_session.id, host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port, protocol: "http://")) do
        v.conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end    
    end.response
    render xml: response
  end
  
    
  
end