class CallStats::Summary
  attr_reader :campaign

  delegate :all_voters, to: :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def percent_of_all_voters(number)
    quo = number / all_voters_count.to_f
    "#{(quo * 100).ceil}%"
  end

  def all_voters_count
    @all_voters_count ||= all_voters.count
  end

  def per_status_counts
    @per_status_counts ||= all_voters.select('status').group("status").count
  end

  def dialed_and_complete_count
    @dialed_and_complete_count ||= all_voters.where({
      status: CallAttempt::Status.completed_list(campaign),
      call_back: false
    }).count
  end

  def not_dialed_count
    @not_dialed_count ||= all_voters.where(status: CallAttempt::Status.not_dialed_list).count
  end

  def dialed_and_available_for_retry_count
    @dialed_and_available_for_retry_count ||= all_voters.available_for_retry(campaign).count
  end

  def dialed_and_not_available_for_retry_count
    @dialed_and_not_available_for_retry_count ||= all_voters.not_available_for_retry(campaign).count
  end
end