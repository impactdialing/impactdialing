class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign
  delegate :households, to: :campaign
  delegate :dial_queue, to: :campaign

private
  def bitmasks
    {
      dnc:          Household.bitmask_for_blocked(:dnc),
      cell:         Household.bitmask_for_blocked(:cell),
      cell_and_dnc: Household.bitmask_for_blocked(:dnc, :cell)
    }
  end

public
  def initialize(campaign)
    @campaign = campaign
  end

  def total_households
    @total_households ||= campaign.list_stats[:total_numbers].to_i
  end

  def not_dialed
    @not_dialed ||= dial_queue.available.count(:active, '-inf', '2.0')
  end

  def completed
    @completed ||= dial_queue.completed.count(:completed, '-inf', '+inf')
  end

  def retrying
    @retrying ||= dial_queue.available.count(:active, '2.0', '+inf')
  end

  def pending_retry
    @pending_retry ||= dial_queue.recycle_bin.count(:bin, '-inf', '+inf')
  end

  def households_blocked_by_dnc
    @households_blocked_by_dnc ||= dial_queue.blocked.count(:blocked, bitmasks[:dnc], bitmasks[:cell_and_dnc])
  end

  def households_blocked_by_cell
    @households_blocked_by_cell ||= dial_queue.blocked.count(:blocked, bitmasks[:cell], bitmasks[:cell]) +
                                    dial_queue.blocked.count(:blocked, bitmasks[:cell_and_dnc], bitmasks[:cell_and_dnc])
  end

  def total_households_to_dial
    not_dialed + retrying
  end

  def total_households_not_to_dial
    dial_queue.blocked.count(:blocked, '-inf', '+inf') +
    completed + pending_retry
  end
end
