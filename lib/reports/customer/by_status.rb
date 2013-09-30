# def account_caller_usage
#   @account = Account.find(params[:id])
#   @callers = @account.callers
#   @from_date, @to_date = set_date_range_account(@account, params[:from_date], params[:to_date])

#   # account_usage = AccountUsage.new(@account, @from_date, @to_date)
#     @account = account
#     @from_date = from_date
#     @to_date = to_date
#     @campaigns = @account.all_campaigns
#     @callers = @account.callers
#     @campaign_ids = @campaigns.collect{|x| x.id}
#     @caller_ids = @callers.collect{|x| x.id}

#   # @billiable_total = account_usage.callers_billable_usage
#     caller_times = CallerSession.where("caller_id in (?)",@caller_ids).between(@from_date, @to_date).where("caller_type = 'Phone'").group("caller_id").sum('ceil(tDuration/60)')
#     lead_times = CallAttempt.where("caller_id in (?)",@caller_ids).between(@from_date, @to_date).group("caller_id").sum('ceil(tDuration/60)')
#     total_times = {}
#     @caller_ids.each do |caller_id|
#       total_times[caller_id] = sanitize(caller_times[caller_id]).to_i + sanitize(lead_times[caller_id]).to_i
#     end
#     total_times

#   # @status_usage = account_usage.callers_status_times
#     CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
#      where("campaign_id in (?) and caller_id is null",@campaign_ids).
#      between(@from_date, @to_date).group("status").
#      sum('ceil(tDuration/60)')
#   @final_total = @billiable_total.values.inject(0){|sum,x| sum+x} +
#                   sanitize_dials(@status_usage[CallAttempt::Status::ABANDONED]).to_i +
#                   sanitize_dials(@status_usage[CallAttempt::Status::VOICEMAIL]).to_i +
#                   sanitize_dials(@status_usage[CallAttempt::Status::HANGUP]).to_i
# end
class Reports::Customer::ByStatus
  attr_reader :billable_minutes
public
  def initialize(billable_minutes, account)
    @billable_minutes = billable_minutes
    @account = account
  end

  def build
    relation = @billable_minutes.relation(:call_attempts)
    relation = @billable_minutes.from_to(relation)
    relation = @billable_minutes.without_callers(relation)
    relation = @billable_minutes.with_campaigns(relation, campaign_ids)
    @billable_minutes.sum( relation.group('status') )
  end
private
  def campaign_ids
    @campaign_ids ||= Campaign.where(account_id: @account.id).pluck(:id)
  end
end
