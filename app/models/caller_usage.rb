class CallerUsage  
  def initialize(caller, campaign, from_date, to_date)
    @caller = caller
    @campaign = campaign
    @from_date = from_date
    @to_date = to_date
  end
  
  def time_logged_in
    round_for_utilization(CallerSession.time_logged_in(@caller, @campaign, @from_date, @to_date))
  end
  
  def time_on_call
    round_for_utilization(CallAttempt.time_on_call(@caller, @campaign, @from_date, @to_date))
  end
  
  def time_in_wrapup
    round_for_utilization(CallAttempt.time_in_wrapup(@caller, @campaign, @from_date, @to_date))
  end
  
  def time_onhold
    round_for_utilization(CallerSession.time_logged_in(@caller, @campaign, @from_date, @to_date).to_f - CallAttempt.time_on_call(@caller, @campaign, @from_date, @to_date).to_f - CallAttempt.time_in_wrapup(@caller, @campaign, @from_date, @to_date).to_f)
  end
  
  def caller_time
    CallerSession.caller_time(@caller, @campaign, @from_date, @to_date)
  end
  
  def lead_time
    CallAttempt.lead_time(@caller, @campaign, @from_date, @to_date)
  end
  
  def total_time
    caller_time + lead_time
  end
  
  def round_for_utilization(seconds)
    (seconds.to_f/60).ceil.to_s
  end  
end
