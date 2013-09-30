class Reports::Customer::ByCampaign
  attr_reader :billable_minutes
public
  def initialize(billable_minutes, account)
    @billable_minutes = billable_minutes
    @account = account
  end

  def build
    groups = billable_minutes.groups(campaign_ids, 'campaigns')
    billable_minutes.calculate_group_total(groups)
  end

private
  def campaign_ids
    @campaign_ids ||= Campaign.where(account_id: @account.id).pluck(:id)
  end
end
