class BasicSubscription < Subscription

  def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER]]
  end

  def transfer_types
    []
  end

  def caller_groups_enabled?
    false
  end

  def minutes_per_caller
    1000.00
  end

  def price_per_caller
    49.00
  end

  def campaign_reports_enabled?
    false
  end

  def caller_reports_enabled?
    false
  end

  def call_recording_enabled?
    false
  end

  def dashboard_enabled?
    false
  end

  def debit(call_time)
    updated_minutes = minutes_utlized + call_time
    self.update_attributes(minutes_utlized: updated_minutes)
  end

  def can_dial?
    available_minutes > 0
  end


end