require 'spec_helper'

describe AccountUsageMailer do
  include ExceptionMethods

  let(:white_labeled_email){ 'info@stonesphones.com' }
  let(:white_label){ 'stonesphonesdialer' }

  let(:from_date){ 10.days.ago }
  let(:to_date){ 2.days.ago }

  let(:campaigns){ [] }
  let(:account) do
    double('Account', {
      id: 1,
      all_campaigns: campaigns
    })
  end

  let(:user) do
    double('User', {
      account: account,
      email: 'user@test.com'
    })
  end
  let(:values){ [23, 45] }
  let(:grand_total) do
    values.inject(:+)
  end
  let(:billable_minutes) do
    double('Reports::BillableMinutes', {
      calculate_total: grand_total
    })
  end
  let(:billable_totals) do
    double('Built report', {
      values: values
    })
  end
  let(:report) do
    double('Reports::Customer::ByCampaign', {
      build: billable_totals
    })
  end

  before(:each) do
    WebMock.allow_net_connect!
    @mandrill = double
    @mailer = AccountUsageMailer.new(user)
    @mailer.stub(:email_domain).and_return({'email_addresses'=>['email@impactdialing.com', white_labeled_email]})

    Reports::BillableMinutes.should_receive(:new).
      with(from_date, to_date).
      and_return(billable_minutes)
  end

  it 'delivers account-wide campaign usage report as html' do
    Reports::Customer::ByCampaign.should_receive(:new).
      with(billable_minutes, account).
      and_return(report)

    expected_html = AccountUsageRender.new.by_campaigns(:html, billable_totals, grand_total, campaigns)
    expected_text = AccountUsageRender.new.by_campaigns(:text, billable_totals, grand_total, campaigns)

    @mailer.should_receive(:send_email).with({
      :subject => "Campaign Usage Report: #{from_date} - #{to_date}",
      :html => expected_html,
      :text => expected_text,
      :from_name => 'Impact Dialing',
      :from_email => 'email@impactdialing.com',
      :to=>[{email: user.email}],
      :track_opens => true,
      :track_clicks => true
    })
    @mailer.by_campaigns(from_date, to_date)
  end
end
