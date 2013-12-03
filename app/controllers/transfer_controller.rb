require Rails.root.join("lib/twilio_lib")
class TransferController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def connect
    transfer_attempt = TransferAttempt.includes(:transfer).find(params[:id])

    transfer_dialer = TransferDialer.new(transfer_attempt.transfer)
    xml = transfer_dialer.connect(transfer_attempt)

    render xml: xml
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
    # Twilio StatusCallback (async after call has completed)
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_attempt.update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]], :call_end => Time.now)
    response = case params[:CallStatus] #using the 2010 api
                when "no-answer", "busy", "failed"
                  transfer_attempt.caller_session.publish('transfer_busy', {})
                  # transfer_attempt.fail
                  Twilio::Verb.new do |v|
                    v.say "The transfered call was not answered "
                    v.hangup
                  end.response
                else
                  # transfer_attempt.hangup
                  Twilio::TwiML::Response.new{|r| r.Hangup}.text
                end
    render :xml => response
  end

  def dial
    transfer        = Transfer.find params[:transfer][:id]
    caller_session  = CallerSession.find params[:caller_session]
    call            = Call.find params[:call]
    voter           = Voter.find params[:voter]

    transfer_dialer = TransferDialer.new(transfer)
    json            = transfer_dialer.dial(caller_session, call, voter)

    render json: json
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
