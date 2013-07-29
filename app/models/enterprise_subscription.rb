class EnterpriseSubscription

  def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]]
  end

  def transfers
    [Transfer::Type::WARM, Transfer::Type::COLD]
  end

  def minutes_per_caller
    2500.00
  end

  def price_per_caller
    99.00
  end

  def caller_groups
    true
  end

  def campaign_reports
    true
  end

  def caller_reports
    true
  end


end