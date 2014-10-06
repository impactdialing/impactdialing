class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def recently_dialed
    @recently_dialed ||= all_voters.recently_dialed_households(campaign.recycle_rate).pluck(:phone)
  end

  def percent_of_all_voters(number)
    quo = number / all_voters_count.to_f
    "#{(quo * 100).ceil}%"
  end

  def all_voters_count
    @all_voters_count ||= all_voters.count(:id)
  end

  def per_status_counts
    @per_status_counts ||= all_voters.select('status').group("status").count(:id)
  end

  def dialed_and_complete_count
    @dialed_and_complete_count ||= all_voters.dialed.uniq.completed(campaign).count
  end

  def dialed_count
    @dialed_count ||= all_voters.dialed.count
  end

  def ringing_count
    @ringing_count ||= all_voters.ringing.count
  end

  def failed_count
    @failed_count ||= all_voters.failed.count
  end

  def not_dialed_count
    @not_dialed_count ||= all_voters.not_dialed.count
  end

  def dialed_and_available_for_retry_count
    @dialed_and_available_for_retry_count ||= all_voters.dialed.available_list(campaign).without(recently_dialed).count
  end

  def households_dialed_and_available_for_retry_count
    @households_dialed_and_available_for_retry_count ||= all_voters.dialed.available_list(campaign).without(recently_dialed).select('DISTINCT(phone)').count
  end

  def dialed_and_not_available_for_retry_count
    @dialed_and_not_available_for_retry_count ||= all_voters.dialed.not_available_list(campaign).count
  end
end