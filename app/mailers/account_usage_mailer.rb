require 'reports'

class AccountUsageMailer < MandrillMailer
  attr_reader :user, :account

  def initialize(user)
    super
    @user    = user
    @account = user.account
  end

  def by_campaigns(from_date, to_date)
    billable_minutes = Reports::BillableMinutes.new(from_date, to_date)
    by_campaign      = Reports::Customer::ByCampaign.new(billable_minutes, account)

    billable_totals  = by_campaign.build

    grand_total      = billable_minutes.calculate_total(billable_totals.values)

    campaigns        = account.all_campaigns.select('id, name')

    html = AccountUsageRender.new.by_campaigns(:html, billable_totals, grand_total, campaigns)
    text = AccountUsageRender.new.by_campaigns(:text, billable_totals, grand_total, campaigns)

    response = send_email({
      :subject => "Campaign Usage Report: #{from_date} - #{to_date}",
      :html => html,
      :text => text,
      :from_name => 'Impact Dialing',
      :from_email => FROM_EMAIL,
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
  end

  def by_callers
  end
end