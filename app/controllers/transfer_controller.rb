require Rails.root.join("lib/twilio_lib")
class TransferController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def connect
    transfer_attempt = TransferAttempt.includes(:transfer).find(params[:id])

    transfer_dialer = TransferDialer.new(transfer_attempt.transfer)
    xml = transfer_dialer.connect(transfer_attempt)

    logger.debug "DoublePause: Transfer#connect SessionKey: #{transfer_attempt.session_key}"
    if transfer_attempt.warm_transfer?
      RedisCallerSession.add_party(transfer_attempt.session_key)
    end
    render xml: xml
  end

  def disconnect
    logger.debug "DoublePause: Transfer#disconnect - #{params}"
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
    logger.debug "DoublePause: Transfer#dial"
    transfer        = Transfer.find params[:transfer][:id]
    caller_session  = CallerSession.find params[:caller_session]
    call            = Call.find params[:call]
    voter           = Voter.find params[:voter]

    transfer_dialer = TransferDialer.new(transfer)
    json            = transfer_dialer.dial(caller_session, call, voter)

    render json: json
  end


  def callee
    logger.debug "DoublePause: Transfer#callee SessionKey: #{params[:session_key]}"

    caller_session = CallerSession.find_by_session_key(params[:session_key])

    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(caller_session.session_key, :startConferenceOnEnter => true, :endConferenceOnExit => true, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end
    end.response
    if params[:transfer_type] == 'warm'
      RedisCallerSession.add_party(params[:session_key])
    end
    caller_session.publish("contact_joined_transfer_conference",{})
    render xml: response
  end

  def caller
    logger.debug "DoublePause: Transfer#caller SessionKey: #{params[:session_key]}"
    caller_session = CallerSession.find(params[:caller_session])
    caller = Caller.find(caller_session.caller_id)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, action: pause_caller_url(caller, session_id:  caller_session.id, transfer_session_key: params[:session_key], host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port, protocol: "http://")) do
        v.conference(params[:session_key], :startConferenceOnEnter => true, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET')
      end
    end.response
    RedisCallerSession.add_party(params[:session_key])
    caller_session.publish("caller_joined_transfer_conference",{})
    render xml: response
  end
end
