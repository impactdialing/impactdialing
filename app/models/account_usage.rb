class AccountUsage
  
  def initialize(account, from_date, to_date)
    @account = account
    @from_date = from_date
    @to_date = to_date
  end
  
  def billable_usage
    campaigns = @account.campaigns
    campaign_ids = campaigns.collect{|x| x.id}
    caller_times = CallerSession.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).where("tCaller is NOT NULL").group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)')      
    lead_times =   CallAttempt.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)')
    transfer_times = TransferAttempt.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)')
    calculate_total_billable_times(campaign_ids, caller_times, lead_times, transfer_times)
  end
  
  def total_minutes
    time_logged_in = CallerSession.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).group('campaign_id').sum('TIMESTAMPDIFF(SECOND ,starttime,endtime)')
    time_on_call = CallAttempt.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).group('campaign_id').sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)')
    time_in_wrapup = CallAttempt.where("campaign_id in (?)",campaign_ids).between(@from_date, @to_date).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).group('campaign_id').sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)')
    
    time_onhold = round_for_utilization(CallerSession.time_logged_in(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_on_call(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_in_wrapup(nil, @campaign, @from_date, @to_date).to_f)
    
  end
  
  def calculate_total_billable_times(campaign_ids, caller_times, lead_times, transfer_times)
    total_times = {}      
    campaign_ids.each do |campaign_id|
      total_times[campaign_id] = sanitize(caller_times[campaign_id]).to_i + sanitize(lead_times[campaign_id]).to_i + sanitize(transfer_times[campaign_id]).to_i
    end
    total_times    
  end
  
  def sanitize(count)
    count.nil? ? 0 : count
  end
  
  def round_for_utilization(seconds)
    (seconds.to_f/60).ceil.to_s
  end
  
  
end