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
    transfer_attempt.update_attribute(:status, CallAttempt::Status::SUCCESS)
    dialed_call = transfer_attempt.caller_session.dialed_call
    if dialed_call.try(:transferred?, transfer_attempt.id)
      transfer_attempt.caller_session.pushit('transfer_conference_ended', {})
    end
    render xml: Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end

  def end
    # Twilio StatusCallback (async after call has completed)
    transfer_attempt = TransferAttempt.find(params[:id])
    transfer_dialer  = TransferDialer.new(transfer_attempt.transfer)

    transfer_attempt.update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]], :call_end => Time.now)

    case params[:CallStatus] #using the 2010 api
    when "no-answer", "busy", "failed"
      transfer_attempt.caller_session.pushit('transfer_busy', {status: params[:CallStatus], label: transfer_attempt.transfer.label})
    end

    render nothing: true
  end

  def dial
    logger.debug "DoublePause: Transfer#dial"
    transfer        = Transfer.find params[:transfer][:id]
    caller_session  = CallerSession.find params[:caller_session]

    transfer_dialer = TransferDialer.new(transfer)
    json            = transfer_dialer.dial(caller_session)

    render json: json
  end

  def callee
    transfer_attempt = TransferAttempt.includes(:caller_session).find_by_session_key params[:session_key]
    caller_session   = transfer_attempt.caller_session

    response = Twilio::TwiML::Response.new do |v|
      v.Dial(:hangupOnStar => true) do
        v.Conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end
    end.text

    caller_session.pushit("contact_joined_transfer_conference",{})
    render xml: response
  end

  def caller
    caller_session = CallerSession.find(params[:caller_session])
    caller = Caller.find(caller_session.caller_id)
    response = Twilio::TwiML::Response.new do |v|
      v.Dial(:hangupOnStar => true, action: pause_caller_url(caller, session_id:  caller_session.id, transfer_session_key: params[:session_key], host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port, protocol: "http://")) do
        v.Conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end
    end.text
    caller_session.pushit("caller_joined_transfer_conference",{})
    render xml: response
  end
end
