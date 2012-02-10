require Rails.root.join("lib/twilio_lib")
class TransferController < ApplicationController
  
  def connect
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attribute(:connecttime, Time.now)
    transfer_attempt.redirect_callee
    if transfer_attempt.transfer_type == Transfer::Type::WARM
      transfer_attempt.redirect_caller
    else
      conference_sid = transfer_attempt.caller_session.get_conference_id
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Conference.kick_participant(conference_sid, transfer_attempt.caller_session.sid)
    end
    render xml: transfer_attempt.conference(transfer_attempt.caller_session, transfer_attempt.call_attempt)        
  end
  
  def disconnect
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attributes(:status => CallAttempt::Status::SUCCESS)
    render xml: Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end
  
  def end
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]], :call_end => Time.now)
    response = case params[:CallStatus] #using the 2010 api
                 when "no-answer", "busy", "failed"
                   transfer_attempt.fail
                 else
                   transfer_attempt.hangup
               end
    render :xml => response    
  end
  
  def dial
    transfer = Transfer.find(params[:transfer][:id])
    caller_session = CallerSession.find(params[:caller_session])    
    call_attempt = CallAttempt.find(params[:call_attempt])
    voter = Voter.find(params[:voter])
    transfer.dial(caller_session, call_attempt, voter, transfer.transfer_type)    
    render nothing: true
  end
  
  def start_conference
    
  end
  
  def callee
    caller_session = CallerSession.find(params[:caller_session])
    caller = Caller.find(caller_session.caller_id)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, action: pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => caller_session.id)) do
        v.conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => true, :beep => false, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
      end
    end.response
    render xml: response    
  end
  
  def caller
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => false, :beep => false, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
      end    
    end.response
    render xml: response
  end
    
  
end