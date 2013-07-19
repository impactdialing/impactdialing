class BasicSubscription

  def campaign_types
    [Campaign::Type::Preview, Campaign::Type::Power]
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