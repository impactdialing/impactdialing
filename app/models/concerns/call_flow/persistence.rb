class CallFlow::Persistence
  attr_reader :campaign, :dialed_call, :household_record

private
  def call_data
    @call_data ||= dialed_call.storage.attributes
  end

  def household_status
    call_data[:mapped_status] || CallAttempt::Status::MAP[call_data[:status]]
  end

  def voter_system_fields
    @voter_system_fields ||= Voter::UPLOAD_FIELDS + ['voter_list_id']
  end

  def phone
    call_data[:phone]
  end

  def dial_queue_households
    CallFlow::DialQueue::Households.new(campaign)
  end

  def caller_session
    return nil if caller_session_sid.nil?
    @caller_session ||= CallerSession.where(sid: caller_session_sid).first
  end

  def caller_session_sid
    call_data[:caller_session_sid]
  end

public
  def initialize(dialed_call, campaign, household_record)
    @dialed_call      = dialed_call
    @campaign         = campaign
    @household_record = household_record
  end
end

