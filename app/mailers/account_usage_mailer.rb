require 'reports'

class AccountUsageMailer < MandrillMailer
  attr_reader :user, :account

private
  def format_date(date)
    date.strftime("%b %e %Y")
  end

public
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
    campaigns        = account.all_campaigns
    html             = AccountUsageRender.new.by_campaigns(:html, billable_totals, grand_total, campaigns)
    text             = AccountUsageRender.new.by_campaigns(:text, billable_totals, grand_total, campaigns)

    send_email({
      :subject => "Campaign Usage Report: #{format_date(from_date)} - #{format_date(to_date)}",
      :html => html,
      :text => text,
      :from_name => 'Impact Dialing',
      :from_email => FROM_EMAIL,
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
  end

  def by_callers(from_date, to_date)
    billable_minutes = Reports::BillableMinutes.new(from_date, to_date)
    by_caller        = Reports::Customer::ByCaller.new(billable_minutes, account)
    by_status        = Reports::Customer::ByStatus.new(billable_minutes, account)
    billable_totals  = by_caller.build
    status_totals    = by_status.build
    grand_total      = billable_minutes.calculate_total(billable_totals.values)
    callers          = account.callers
    html             = AccountUsageRender.new.by_callers(:html, billable_minutes, status_totals, grand_total, callers)
    text             = AccountUsageRender.new.by_callers(:text, billable_minutes, status_totals, grand_total, callers)

    send_email({
      :subject => "Caller Usage Report: #{format_date(from_date)} - #{format_date(to_date)}",
      :html => html,
      :text => text,
      :from_name => 'Impact Dialing',
      :from_email => FROM_EMAIL,
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
  end
end