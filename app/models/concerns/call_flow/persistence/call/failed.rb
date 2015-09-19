class CallFlow::Persistence::Call::Failed
  attr_reader :failed_call, :campaign, :household_record, :phone

  def initialize(campaign_id, phone)
    @failed_call      = CallFlow::Call::Failed.new(campaign_id, phone)
    @phone            = phone
    @campaign         = Campaign.find(campaign_id)
    @household_record = campaign.households.where(phone: phone).first
  end

  def persist_call_outcome
    @household_record = call_persistence.create_or_update_household_record

    leads.import_records
    call_attempt_record = call_persistence.create_call_attempt
    leads.del_household_from_presented(phone)
  end

  def call_persistence
    @call_persistence ||= CallFlow::Persistence::Call.new(failed_call, campaign, household_record)
  end

  def leads
    @leads ||= CallFlow::Persistence::Leads.new(failed_call, campaign, household_record)
  end
end

