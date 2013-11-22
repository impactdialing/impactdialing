class TransferDialer
  attr_reader :transfer, :transfer_attempt, :caller_session, :call, :voter

private
  def update_transfer_attempt(response)
    if response.error?
      attempt_attrs = {status: CallAttempt::Status::FAILED}
    else
      attempt_attrs = {sid: response.call_sid}
    end
    transfer_attempt.update_attributes(attempt_attrs)
  end

  def create_transfer_attempt
    transfer.transfer_attempts.create({
      session_key: generate_session_key,
      campaign_id: caller_session.campaign_id,
      status: CallAttempt::Status::RINGING,
      caller_session_id: caller_session.id,
      call_attempt_id: call.call_attempt.id,
      transfer_type: transfer.transfer_type
    })
  end

  def generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

public
  def initialize(transfer, caller_session, call, voter)
    @transfer       = transfer
    @caller_session = caller_session
    @call           = call
    @voter          = voter
  end

  def dial
    @transfer_attempt = create_transfer_attempt
    response = Providers::Phone::Call.make_for(transfer, :connect)
    update_transfer_attempt(response)
    return {type: transfer.transfer_type}
  end

  def end
  end

  def connect
  end
end