class CallFlow::Jobs::Persistence::DialedCall
  include Sidekiq::Worker

  attr_reader :dialed_call, :call_data, :caller_session_sid, :phone, :campaign_id, :campaign, :household_status

  sidekiq_options({
    queue: :persistence,
    retry: true,
    failures: true,
    backtrace: true
  })

  def perform(account_sid, call_sid)
    @dialed_call        = CallFlow::Call::Dialed.new(account_sid, call_sid)
    @call_data          = dialed_call.storage
    @caller_session_sid = call_data['caller_session_sid']
    @phone              = call_data['phone']
    @campaign_id        = call_data['campaign_id']
    @household_status   = call_data['mapped_status'] || CallAttempt::Status::MAP[call_data['status']]
    @campaign           = Campaign.find(campaign_id)

    if (household = Household.where(phone: phone).first).present?
      persist_subsequent_calls_to_household(household)
    else
      persist_first_call_to_household
    end
  end

  def persist_subsequent_calls_to_household(household)
    dispositioned_voter = nil

    if call_data['status'] == 'completed'
    end

    household.update_attributes!(status: household_status)
    create_call_attempt_record(household, caller_session, dispositioned_voter)
  end

  def persist_first_call_to_household
    # create Household record
    household   = campaign.households.create!({
      account_id: campaign.account_id,
      phone: phone,
      status: household_status
    })

    # create Voter record(s)
    redis_household     = dial_queue_households.find(phone)
    leads               = redis_household['leads']
    dispositioned_voter = nil
    uuid_to_id_map      = {}

    if call_data['status'] == 'completed'
      # create 1 voter record & attach to call attempt
      lead                                = leads.detect{|ld| ld[:uuid] == call_data[:lead_uuid]}
      dispositioned_voter, uuid_to_id_map = create_dispositioned_voter_record(household, lead)
      leads.reject!{|ld| ld[:uuid] == call_data[:lead_uuid]}
    end

    not_called_uuid_to_id_map = create_voter_records(household, leads)
    uuid_to_id_map.merge!(not_called_uuid_to_id_map)
    dial_queue_households.update_leads_with_sql_ids(phone, uuid_to_id_map)

    create_call_attempt_record(household, caller_session, dispositioned_voter)
  end

  def create_dispositioned_voter_record(household_record, lead)
    voter_attrs = {}
    voter_system_fields.each do |field|
      voter_attrs[field] = lead[field]
    end

    voter_attrs.merge!({
      account_id: campaign.account_id,
      campaign_id: campaign.id,
      status: household_status
    })

    voter_record = household_record.voters.create(voter_attrs)

    [
      voter_record,
      {
        lead[:uuid] => voter_record.id
      }
    ]
  end

  def voter_system_fields
    @voter_system_fields ||= Voter::UPLOAD_FIELDS + ['voter_list_id']
  end

  def create_voter_records(household_record, leads)
    uuid_to_id_map = {}
    leads.each do |lead|
      voter_attrs = {}
      voter_system_fields.each do |field|
        voter_attrs[field] = lead[field]
      end

      voter_attrs.merge!({
        account_id: campaign.account_id,
        campaign_id: campaign.id
      })

      voter_record = household_record.voters.create(voter_attrs)
      uuid_to_id_map[lead[:uuid]] = voter_record.id
    end

    uuid_to_id_map
  end

  def create_call_attempt_record(household, caller_session=nil, dispositioned_voter=nil)
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

  def dial_queue_households
    @dial_queue_households ||= CallFlow::DialQueue::Households.new(campaign)
  end

  def caller_session
    return nil if caller_session_sid.nil?
    @caller_session ||= CallerSession.where(sid: caller_session_sid).first
  end
end

