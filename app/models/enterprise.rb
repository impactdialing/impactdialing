class Enterprise < Subscription
  class UpgradeError < ArgumentError; end

  def self.upgrade(account)
    failed_subscription = account.zero_all_subscription_minutes!
    if failed_subscription.kind_of? Subscription
      raise UpgradeError, "Upgrade to Enterprise failed to update existing minutes: "+
                          "#{failed_subscription.errors.full_messages.to_sentence}."
    end

    new_subscription = Enterprise.new({
      account_id: account.id,
      subscription_start_date: DateTime.now,
      subscription_end_date: DateTime.now+10.years
    })

    unless new_subscription.save
      raise UpgradeError, "Upgrade to Enterprise failed to update the new subscription: "+
                          "#{new_subscription.errors.full_messages.to_sentence}."
    end

    if account.respond_to? :upgraded_to_enterprise
      account.upgraded_to_enterprise
    end

    return new_subscription
  end

  def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]]
  end

  def transfer_types
    [Transfer::Type::WARM, Transfer::Type::COLD]
  end

  def minutes_per_caller
    2500.00
  end

  def price_per_caller
    99.00
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

  def can_dial?
    true
  end


  def debit(call_time)
    true
  end

  def subscribe
  end



end