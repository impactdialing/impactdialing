class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign
  delegate :households, to: :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def dialed_and_complete_count
    @dialed_and_complete_count ||= all_voters.completed(campaign).count
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

  def voters_not_reached
    @voters_not_reached ||= all_voters.with_enabled(:list).where(status: Voter::Status::NOTCALLED).joins(:household).where('households.blocked = 0').count
  end

  def dialed_and_available_for_retry_count
    @dialed_and_available_for_retry_count ||= households.active.dialed.available(campaign).count
  end

  def dialed_and_not_available_for_retry_count
    @dialed_and_not_available_for_retry_count ||= households.dialed.not_available(campaign).count
  end
end
