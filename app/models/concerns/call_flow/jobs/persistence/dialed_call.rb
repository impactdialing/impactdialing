class CallFlow::Jobs::Persistence::DialedCall
  include Sidekiq::Worker

  sidekiq_options({
    queue: :persistence,
    retry: true,
    failures: true,
    backtrace: true
  })

  def perform(account_sid, call_sid)
    dialed_call        = CallFlow::Call::Dialed.new(account_sid, call_sid)
    call_data          = dialed_call.storage
    caller_session_sid = call_data['caller_session_sid']
    phone              = call_data['phone']
    campaign_id        = call_data['campaign_id']
    household_status   = call_data['mapped_status'] || CallAttempt::Status::MAP[call_data['status']]
    campaign           = Campaign.find(campaign_id)

    caller_session = nil
    if caller_session_sid.present?
      caller_session = CallerSession.where(sid: caller_session_sid).first
    end

    # create Household record
    household   = campaign.households.create!({
      account_id: campaign.account_id,
      phone: phone,
      status: household_status
    })

    # create Voter record(s)
    system_fields       = Voter::UPLOAD_FIELDS + ['voter_list_id']
    redis_households    = CallFlow::DialQueue::Households.new(campaign, :pending_persistence)
    redis_household     = redis_households.find(phone)
    leads               = redis_household['leads']
    dispositioned_voter = nil

    leads.each do |lead|
      # all lead statuses inherit from household except 'completed' (aka dispositioned) calls
      status = call_data['status'] != 'completed' ? household_status : nil

      if call_data['lead_uuid'] == lead[:uuid]
        # only the dispositioned lead inherits household status, others get default of notcalled
        status = household_status
      end

      voter_attrs = {}
      system_fields.each do |field|
        voter_attrs[field] = lead[field]
      end

      voter_attrs.merge!({
        account_id: campaign.account_id,
        campaign_id: campaign.id
      })

      voter_attrs[:caller_session_id] = caller_session.id unless caller_session.nil?
      voter_attrs[:status] = status unless status.nil?

      voter_record = household.voters.create(voter_attrs)

      if call_data['lead_uuid'] == lead[:uuid]
        dispositioned_voter = voter_record
      end
    end

    # create CallAttempt record
    call_attempt_attrs = {
      household_id: household.id,
      campaign_id: campaign.id,
      status: household_status,
      sid: call_data['sid'],
      dialer_mode: call_data['campaign_type']
    }

    if call_data['recording_id'].present?
      # todo...
      # a message was dropped
      #call_attempt_attrs[:recording_id] = call_data['recording_id']
      #call_attempt_attrs[:recording_delivered_manually] = ...
    end

    unless call_data['recording_url'].blank?
      call_attempt_attrs[:recording_url]      = call_data['recording_url']
      call_attempt_attrs[:recording_duration] = call_data['recording_duration']
    end
    
    unless caller_session.nil?
      call_attempt_attrs[:caller_session_id] = caller_session.id
      call_attempt_attrs[:caller_id]         = caller_session.caller_id
    end

    call_attempt_attrs[:voter_id] = dispositioned_voter.id unless dispositioned_voter.nil?

    CallAttempt.create(call_attempt_attrs)
  end
end

