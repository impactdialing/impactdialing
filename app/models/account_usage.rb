class AccountUsage

  def initialize(account, from_date, to_date)
    @account = account
    @from_date = from_date
    @to_date = to_date
    @campaigns = @account.all_campaigns
    @callers = @account.callers
    @campaign_ids = @campaigns.collect{|x| x.id}
    @caller_ids = @callers.collect{|x| x.id}
  end

  def billable_usage
    caller_times = CallerSession.where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).where("caller_type = 'Phone' ").group("campaign_id").sum('ceil(tDuration/60)')
    lead_times =  CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
      where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).
      group("campaign_id").sum('ceil(tDuration/60)')
    transfer_times = TransferAttempt.where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).group("campaign_id").sum('ceil(tDuration/60)')
    calculate_total_billable_times(caller_times, lead_times, transfer_times)
  end

  def callers_billable_usage
    caller_times = CallerSession.where("caller_id in (?)",@caller_ids).between(@from_date, @to_date).where("caller_type = 'Phone'").group("caller_id").sum('ceil(tDuration/60)')
    lead_times = CallAttempt.where("caller_id in (?)",@caller_ids).between(@from_date, @to_date).group("caller_id").sum('ceil(tDuration/60)')
    total_times = {}
    @caller_ids.each do |caller_id|
      total_times[caller_id] = sanitize(caller_times[caller_id]).to_i + sanitize(lead_times[caller_id]).to_i
    end
    total_times
  end

  def callers_status_times
   CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
     where("campaign_id in (?) and caller_id is null",@campaign_ids).
     between(@from_date, @to_date).group("status").
     sum('ceil(tDuration/60)')
  end


  def calculate_total_billable_times(caller_times, lead_times, transfer_times)
    total_times = {}
    @campaign_ids.each do |campaign_id|
      total_times[campaign_id] = sanitize(caller_times[campaign_id]).to_i + sanitize(lead_times[campaign_id]).to_i + sanitize(transfer_times[campaign_id]).to_i
    end
    total_times
  end

  def sanitize(count)
    count.nil? ? 0 : count
  end


end
