class Trial < Subscription
    def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]]
  end

  def transfer_types
    [Transfer::Type::WARM, Transfer::Type::COLD]
  end

  def caller_groups_enabled?
    true
  end

  def campaign_reports_enabled?
    true
  end

  def caller_reports_enabled?
    true
  end

  def call_recording_enabled?
    true
  end

  def dashboard_enabled?
    true
  end

  def self.build(account_id)
    Trial.create(minutes_utlized: 0, total_allowed_minutes: 50.00, subscription_start_date: DateTime.now,
      account_id: account_id, number_of_callers: 1)
  end

  def debit(call_time)
    updated_minutes = minutes_utlized + call_time
    self.update_attributes(minutes_utlized: updated_minutes)
  end

  def can_dial?
    available_minutes > 0
  end


end