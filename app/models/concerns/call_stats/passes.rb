class CallStats::Passes < CallStats::Summary
public
  def initialize(campaign)
    @campaign = campaign
  end

  def current_pass
    households_dialed.values.max
  end

  def households_dialed
    @houseolds_dialed ||= campaign.call_attempts.group(:household_id).count
  end

  def households_dialed_n_times(n)
    households_dialed.values.select{|dials| dials >= n}.size
  end
end

