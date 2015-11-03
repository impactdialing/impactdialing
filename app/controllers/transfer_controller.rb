require Rails.root.join("lib/twilio_lib")
class TransferController < TwimlController
  skip_before_filter :verify_authenticity_token
  before_filter :abort_caller_if_unprocessable_fallback_url, only: [:caller]
  before_filter :abort_lead_if_unprocessable_fallback_url, only: [
    :connect, :callee, :disconnect
  ]

  if instrument_actions?
    instrument_action :connect, :disconnect, :callee, :caller, :end, :dial
  end

  def connect
    @transfer_attempt = TransferAttempt.includes(:transfer).find(params[:id])
    transfer_dialer   = TransferDialer.new(@transfer_attempt.transfer)
    transfer_dialer.connect(@transfer_attempt)
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
    caller_session.pushit("contact_joined_transfer_conference",{})

    @session_key = transfer_attempt.session_key
  end

  def caller
    @caller_session = CallerSession.find(params[:caller_session])
    @caller = Caller.find(@caller_session.caller_id)
    @session_key = params[:session_key]
    
    @caller_session.pushit("caller_joined_transfer_conference",{})
  end
end
