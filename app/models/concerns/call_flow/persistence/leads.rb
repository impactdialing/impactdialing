class CallFlow::Persistence::Leads < CallFlow::Persistence
  attr_reader :dispositioned_voter

private
  def redis_household
    dial_queue_households.find(phone)
  end

  def active_redis_leads
    redis_household['leads']
  end

  def active_new_redis_leads
    redis_household['leads'].select{|lead| lead['sql_id'].blank?}
  end

  def any_leads_not_persisted?
    active_new_redis_leads.any?
  end

  def leads_without_target
    active_redis_leads.select{|ld| ld['uuid'] != call_data[:lead_uuid]}
  end

  def new_leads_without_target
    leads_without_target.select{|ld| ld['sql_id'].blank?}
  end

public
  def import_records
    leads               = active_redis_leads
    @dispositioned_voter = nil
    uuid_to_id_map      = {}

    if dialed_call.completed? and dialed_call.answered_by_human?
      # create 1 voter record & attach to call attempt
      @dispositioned_voter, uuid_to_id_map = create_or_update_dispositioned_voter_record(target_lead)
    end

    not_called_uuid_to_id_map = create_voter_records(new_leads_without_target)

    if active_new_redis_leads.any?
      uuid_to_id_map.merge!(not_called_uuid_to_id_map)
      dial_queue_households.update_leads_with_sql_ids(phone, uuid_to_id_map)
    end

    @dispositioned_voter
  end

  def target_lead
    active_redis_leads.detect{|ld| ld['uuid'] == call_data[:lead_uuid]}
  end

  def create_voter_records(leads)
    uuid_to_id_map = {}
    
    return uuid_to_id_map if leads.empty?

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

  def create_or_update_dispositioned_voter_record(lead)
    if lead['sql_id'].blank?
      create_dispositioned_voter_record(lead)
    else
      update_dispositioned_voter_record(lead)
    end
  end

  def update_dispositioned_voter_record(lead)
    voter_record = Voter.find(lead['sql_id'])
    voter_record.update_attributes!({
      status: household_status
    })

    [
      voter_record,
      {
        lead[:uuid] => voter_record.id
      }
    ]
  end

  def create_dispositioned_voter_record(lead)
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
end

