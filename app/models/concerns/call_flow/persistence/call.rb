##
# Manages persistence of CallAttempt records from CallFlow::Call::Dialed.
#
class CallFlow::Persistence::Call < CallFlow::Persistence
  def create_household_record
    @household_record = campaign.households.create!({
      account_id: campaign.account_id,
      phone: phone,
      status: household_status,
      presented_at: Time.now.utc
    })
  end

  def update_household_record
    household_record.update_attributes!({
      status: household_status,
      presented_at: Time.now.utc
    })
    household_record
  end

  def create_or_update_household_record
    if household_record.present?
      update_household_record
    else
      create_household_record
    end
  end

  ##
  # Build & create a new CallAttempt record.
  def create_call_attempt(dispositioned_voter=nil)
    call_attempt_attrs = {
      household_id: household_record.id,
      campaign_id: campaign.id,
      status: household_status,
      sid: call_data[:sid],
      dialer_mode: call_data[:campaign_type]
    }

    if call_data[:recording_id].present?
      call_attempt_attrs[:recording_id]                 = call_data[:recording_id]
      call_attempt_attrs[:recording_delivered_manually] = call_data[:recording_delivered_manually].to_i > 0
    end

    unless call_data[:recording_url].blank?
      call_attempt_attrs[:recording_url]      = call_data[:recording_url]
      call_attempt_attrs[:recording_duration] = call_data[:recording_duration]
    end

    unless caller_session.nil?
      call_attempt_attrs[:caller_session_id] = caller_session.id
      call_attempt_attrs[:caller_id]         = caller_session.caller_id
    end

    call_attempt_attrs[:voter_id] = dispositioned_voter.id unless dispositioned_voter.nil?

    ::CallAttempt.create(call_attempt_attrs)
  end
end

