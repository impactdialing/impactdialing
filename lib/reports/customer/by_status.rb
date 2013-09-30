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
