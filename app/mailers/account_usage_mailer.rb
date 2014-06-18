require 'reports'

class AccountUsageMailer < MandrillMailer
  attr_reader :user, :account

private
  def format_date(date)
    d = Date.rfc3339(date)
    d.strftime("%b %e %Y")
  end

public
  def initialize(user, internal_admin=false)
    super
    @user           = user
    @account        = user.account
    @internal_admin = internal_admin
  end

  def internal_admin?
    @internal_admin
  end

  def by_campaigns(from_date, to_date)
    billable_minutes = Reports::BillableMinutes.new(from_date, to_date)
    by_campaign      = Reports::Customer::ByCampaign.new(billable_minutes, account)
    billable_totals  = by_campaign.build
    grand_total      = billable_minutes.calculate_total(billable_totals.values)
    campaigns        = account.all_campaigns
    html             = AccountUsageRender.new.by_campaigns(:html, billable_totals, grand_total, campaigns)
    text             = AccountUsageRender.new.by_campaigns(:text, billable_totals, grand_total, campaigns)
    subject          = "Campaign Usage Report: #{format_date(from_date)} - #{format_date(to_date)}"
    to               = [{email: user.email}]

    send_account_usage_report(to, subject, text, html)
  end

  def by_callers(from_date, to_date)
    billable_minutes = Reports::BillableMinutes.new(from_date, to_date)
    by_caller        = Reports::Customer::ByCaller.new(billable_minutes, account)
    by_status        = Reports::Customer::ByStatus.new(billable_minutes, account)
    billable_totals  = by_caller.build
    status_totals    = by_status.build
    grand_total      = billable_minutes.calculate_total(billable_totals.values)
    callers          = account.callers
    html             = AccountUsageRender.new.by_callers(:html, billable_totals, status_totals, grand_total, callers)
    text             = AccountUsageRender.new.by_callers(:text, billable_totals, status_totals, grand_total, callers)
    subject          = "Caller Usage Report: #{format_date(from_date)} - #{format_date(to_date)}"
    to               = [{email: user.email}]

    send_account_usage_report(to, subject, text, html)
  end

  def send_account_usage_report(to, subject, text, html)
    if internal_admin?
      to = [{email: SALES_EMAIL}, {email: TECH_EMAIL}]
    end

    send_email({
      :subject      => subject,
      :html         => html,
      :text         => text,
      :from_name    => 'Impact Dialing',
      :from_email   => FROM_EMAIL,
      :to           => to,
      :track_opens  => true,
      :track_clicks => true
    })
  end
end
