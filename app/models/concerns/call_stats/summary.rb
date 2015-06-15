class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign
  delegate :households, to: :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def total_households
    @total_households ||= campaign.households.count(:id)
  end

  def not_dialed
    @not_dialed ||= campaign.dial_queue.available.count(:active, '-inf', '2.0')
  end

  def completed
    # health check:
    #   if this returns positive number and households.dialed.count.zero?
    #     then alert/fix because some data was not cached...
    @completed ||= households.active.count -
                   campaign.dial_queue.available.size(:active) -
                   campaign.dial_queue.available.size(:presented) -
                   campaign.dial_queue.recycle_bin.size
  end

  def retrying
    @retrying ||= campaign.dial_queue.available.count(:active, '2.0', '+inf')
  end

  def pending_retry
    @pending_retry ||= campaign.dial_queue.recycle_bin.size
  end

  def households_blocked_by_dnc
    @households_blocked_by_dnc ||= households.with_blocked(:dnc).count
  end

  def households_blocked_by_cell
    @households_blocked_by_cell ||= households.with_blocked(:cell).count
  end

  def total_households_to_dial
    not_dialed + retrying
  end

  def total_households_not_to_dial
    households_blocked_by_dnc +
    households_blocked_by_cell +
    completed + 
    pending_retry
  end
end
