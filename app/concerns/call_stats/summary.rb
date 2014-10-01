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
    @all_voters_count ||= all_voters.count(:id)
  end

  def per_status_counts
    @per_status_counts ||= all_voters.select('status').group("status").count(:id)
  end

  def dialed_and_complete_count
    @dialed_and_complete_count ||= all_voters.dialed.uniq.completed(campaign).count
  end

  def dialed_count
    @dialed_count ||= all_voters.dialed.uniq.count
  end

  def not_dialed_count
    @not_dialed_count ||= all_voters.not_dialed.uniq.count
  end

  def dialed_and_available_for_retry_count
    return @dialed_and_available_for_retry_count if defined?(@dialed_and_available_for_retry_count)

    recently_dialed_numbers               = all_voters.recently_dialed_households(campaign.recycle_rate).pluck(:phone)
    @dialed_and_available_for_retry_count = all_voters.dialed.available_list(campaign).without(recently_dialed_numbers).count
  end

  def dialed_and_not_available_for_retry_count
    return @dialed_and_not_available_for_retry_count if defined?(@dialed_and_not_available_for_retry_count)

    recently_dialed_numbers                   = all_voters.recently_dialed_households(campaign.recycle_rate).pluck(:phone)
    @dialed_and_not_available_for_retry_count = all_voters.dialed.not_available_for_retry(campaign).count
    @dialed_and_not_available_for_retry_count += all_voters.where(phone: recently_dialed_numbers).where('id NOT IN (?)', all_voters.not_available_for_retry(campaign).pluck(:id)).count
  end
end