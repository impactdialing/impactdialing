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

  def total_active_households
    @total_active_households ||= campaign.households.active.count(:id)
  end

  def dialed_count
    @dialed_count ||= (households.dialed.count + ringing_count)
  end

  def ringing_count
    Twillio::InflightStats.new(campaign).get('ringing')
  end

  def failed_count
    @failed_count ||= households.failed.count
  end

  def households_not_dialed_count
    return @households_not_dialed_count if defined?(@households_not_dialed_count)
    
    actual_count                 = households.active.not_dialed.count
    adjusted_count               = actual_count - ringing_count
    @households_not_dialed_count = if adjusted_count < 0
                                     actual_count
                                   else
                                     adjusted_count
                                   end
  end

  def households_completely_dispositioned
    return @households_completely_dispositioned if defined?(@households_completely_dispositioned)
    # count all households where all associated voters have a status of completed
    every                                = all_voters.group(:household_id).count
    completed                            = all_voters.completed(campaign).group(:household_id).count
    @households_completely_dispositioned = every.reject{|id,cnt| completed[id].to_i < cnt}.size + households.failed.count
  end

  def dialed_and_available_for_retry_count
    @dialed_and_available_for_retry_count ||= households.active.dialed.available(campaign).count
  end

  def dialed_and_not_available_for_retry_count
    @dialed_and_not_available_for_retry_count ||= households.dialed.not_available(campaign).count
  end

  def dialed_and_pending_retry
    @dialed_and_pending_retry ||= households.dialed.recently_dialed(campaign).
                                  select('DISTINCT households.id').joins(:voters).where([
                                    '(voters.call_back = ? OR voters.status = ?) AND households.status = ?',
                                    true,
                                    Voter::Status::NOTCALLED,
                                    CallAttempt::Status::SUCCESS
                                  ]).count
  end

  def households_blocked_by_dnc
    @households_blocked_by_dnc ||= households.with_blocked(:dnc).count
  end

  def households_blocked_by_cell
    @households_blocked_by_cell ||= households.with_blocked(:cell).count
  end

  def total_households_to_dial
    households_not_dialed_count + dialed_and_available_for_retry_count
  end

  def total_households_not_to_dial
    households_blocked_by_dnc +
    households_blocked_by_cell +
    households_completely_dispositioned
  end
end
