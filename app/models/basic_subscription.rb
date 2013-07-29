class BasicSubscription

  def campaign_types
    [Campaign::Type::PREVIEW, Campaign::Type::POWER]
  end

  def campaign_type_options
    [[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER]]
  end

  def transfers
    []
  end

  def minutes_per_caller
    1000.00
  end

  def price_per_caller
    49.00
  end


end