class CampaignUsage

  def initialize(campaign, from_date, to_date)
    @campaign = campaign
    @from_date = from_date
    @to_date = to_date
  end

  def time_logged_in
    round_for_utilization(CallerSession.time_logged_in(nil, @campaign, @from_date, @to_date))
  end

  def time_on_call
    round_for_utilization(CallAttempt.time_on_call(nil, @campaign, @from_date, @to_date))
  end

  def time_in_wrapup
    round_for_utilization(CallAttempt.time_in_wrapup(nil, @campaign, @from_date, @to_date))
  end

  def time_onhold
    round_for_utilization(CallerSession.time_logged_in(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_on_call(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_in_wrapup(nil, @campaign, @from_date, @to_date).to_f)
  end

  def caller_time
    CallerSession.caller_time(nil, @campaign, @from_date, @to_date)
  end

  def lead_time
    CallAttempt.lead_time(nil, @campaign, @from_date, @to_date)
  end

  def transfer_time
    @campaign.transfer_time(@from_date, @to_date)
  end

  def voice_mail_time
    @campaign.voicemail_time(@from_date, @to_date)
  end

  def abandoned_time
     @campaign.abandoned_calls_time(@from_date, @to_date)
  end

  def total_time
    caller_time + lead_time + transfer_time + voice_mail_time + abandoned_time
  end

  def round_for_utilization(seconds)
    (seconds.to_f/60).ceil.to_s
  end



end
