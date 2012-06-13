class AccountUsage
  
  def initialize(account, from_date, to_date)
    @account = account
    @from_date = from_date
    @to_date = to_date
    @campaigns = @account.campaigns
    @campaign_ids = @campaigns.collect{|x| x.id}    
  end
  
  def billable_usage
    caller_times = CallerSession.where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).where("tCaller is NOT NULL").group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)')      
    lead_times =   CallAttempt.where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)')
    transfer_times = TransferAttempt.where("campaign_id in (?)",@campaign_ids).between(@from_date, @to_date).group("campaign_id").sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)')
    calculate_total_billable_times(caller_times, lead_times, transfer_times)
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