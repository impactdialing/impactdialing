require Rails.root.join("lib/twilio_lib")
class TransferController < ApplicationController
  
  def connect
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attribute(:connecttime, Time.now)
    transfer_attempt.
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
    transfer.dial(caller_session, call_attempt, voter)    
    render nothing: true
  end
  
  def callee
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)) do
        v.conference(params[:session_key], :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
    end.response
    response    
  end
  
  def caller
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)) do
        v.conference(params[:session_key], :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
    end.response    
    response
  end
  
  
  def redirect_callee_to_new_conference
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, phones_only_caller_index_url(:host => Settings.host, :port => Settings.port, ))    
  end
  
  
end