require 'spec_helper'

describe ReportAccountUsageJob do
  let(:from_date){ 10.days.ago }
  let(:to_date){ 1.day.ago }
  let(:campaigns) do
    []
  end
  let(:account) do
    double('Account', {
      id: 1,
      all_campaigns: campaigns
    })
  end
  let(:user) do
    double('User', {
      id: 1,
      email: 'user@test.com',
      account: account
    })
  end

  before do
    User.stub(:find).with(1){ user }
  end

  describe '.perform(report_type, account, user, from_date, to_date)' do
    describe 'report_type = "campaigns"' do
      it "calls .mail_campaigns_usage(account, user, from_date, to_date)" do
        ReportAccountUsageJob.should_receive(:mail_campaigns_usage).
          with(user.id, from_date, to_date)
        ReportAccountUsageJob.perform('campaigns', user.id, from_date, to_date)
      end
    end

    describe 'report_type = "callers"' do
      it "calls .mail_callers_usage(account, user, from_date, to_date)" do
        ReportAccountUsageJob.should_receive(:mail_callers_usage).
          with(user.id, from_date, to_date)
        ReportAccountUsageJob.perform('callers', user.id, from_date, to_date)
      end
    end

    describe "generating reports" do
      let(:values){ [23, 45] }
      let(:billable_minutes) do
        double('Reports::BillableMinutes', {
          calculate_total: values.inject(:+)
        })
      end
      let(:billable_totals) do
        double('Reports::Customer::ByCampaign', {
          build: nil,
          values: values
        })
      end
      let(:mailer) do
        double('AccountUsageMailer', {
          by_callers: nil,
          by_campaigns: nil
        })
      end
      before do
        AccountUsageMailer.stub(:new).
          with(user).
          and_return(mailer)
      end
      describe '.mail_campaigns_usage(account, user, from_date, to_date)' do
        it "builds the email" do
          mailer.should_receive(:by_campaigns).
            with(from_date, to_date)
          ReportAccountUsageJob.mail_campaigns_usage(user.id, from_date, to_date)
        end
      end

      describe '.mail_callers_usage(account, user, from_date, to_date)' do
        before do
          AccountUsageMailer.stub(:new).
            with(user).
            and_return(mailer)
        end
        it "builds that email" do
          mailer.should_receive(:by_callers).
            with(from_date, to_date)
          ReportAccountUsageJob.mail_callers_usage(user.id, from_date, to_date)
        end
      end
    end

    it 'raises a NoMethodError when report_type is not one of "campaigns" or "callers"' do
      expect{
        ReportAccountUsageJob.perform('nonsense', user.id, from_date, to_date)
      }.to raise_error NoMethodError
    end
  end
end