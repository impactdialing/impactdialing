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

  def create_household_record
    @household_record = campaign.households.create!({
      account_id: campaign.account_id,
      phone: phone,
      status: household_status
    })
  end

  def update_household_record
    household_record.update_attributes!(status: household_status)
  end

  def create_answer_records
  end

  def create_note_response_records
  end

  def call_attempt
    @call_attempt ||= CallFlow::Persistence::DialedCall.new(dialed_call, campaign, household_record)
  end

  def voters
    @voters ||= CallFlow::Persistence::Leads.new(dialed_call, campaign, household_record)
  end

  def answers
    @answers ||= CallFlow::Persistence::Answers.new(dialed_call, campaign, household_record)
  end

  def notes
    @notes ||= CallFlow::Persistence::Notes.new(dialed_call, campaign, household_record)
  end

public
  def initialize(dialed_call, campaign, household_record)
    @dialed_call      = dialed_call
    @campaign         = campaign
    @household_record = household_record
  end

  #def save_call_outcome
  #  if household_record.present? # subsequent dial
  #    update_household_record
  #  else # first dial
  #    create_household_record
  #  end

  #  if any_leads_not_persisted?
  #    voters.import_records
  #  end

  #  call_attempt.create(voters.dispositioned_record)

  #  if dialed_call.answered_by_human?
  #    create_answer_records
  #    create_note_response_records
  #  end 
  #end
end

