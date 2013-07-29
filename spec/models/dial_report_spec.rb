require "spec_helper"

describe DialReport do
  include ApplicationHelper::TimeUtils

  describe "overview" do

    describe "dial and completed" do

      it "should include all successful call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter3 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).beginning_of_day.to_s
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)
      end

      it "should include all failed call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day.to_s
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)
      end

      it "should include all successful failed call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)

        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        voter1.update_attributes(last_call_attempt_time: call_attempt1.created_at)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        voter2.update_attributes(last_call_attempt_time: call_attempt2.created_at)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        voter3.update_attributes(last_call_attempt_time: call_attempt3.created_at)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)
        voter4.update_attributes(last_call_attempt_time: call_attempt4.created_at)

        from_date = CallAttempt.find_all_by_campaign_id(@campaign.id).first.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day.to_s
        to_date = CallAttempt.find_all_by_campaign_id(@campaign.id).last.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.dialed_and_completed.should eq(2)
      end
    end

    describe "available and retry" do

      it "should consider scheduled avaiable and abandoned calls" do
        @campaign = create(:predictive, recycle_rate: 1)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: Time.now - 2.hours)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
        voter4 = create(:voter, campaign: @campaign, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
        voter5 = create(:voter, campaign: @campaign, :status => CallAttempt::Status::ABANDONED)
        from_date = @campaign.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day.to_s
        to_date = Time.now.in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.leads_available_for_retry.should eq(3)
      end
    end

    describe "leads_not_available_for_retry" do

      it "should consider scheduled for later and not available for retry now" do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: Time.now - 2.hours)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
        voter4 = create(:voter, campaign: @campaign, last_call_attempt_time: Time.now - 4.hours, status: CallAttempt::Status::HANGUP)
        voter5 = create(:voter, campaign: @campaign, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED, enabled: true)
        voter6 = create(:voter, campaign: @campaign, :scheduled_date => 12.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
        voter7 = create(:voter, campaign: @campaign, :status => CallAttempt::Status::ABANDONED)
        from_date = @campaign.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day.to_s
        to_date = Time.now.in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.leads_not_available_for_retry.should eq(2)
      end

    end

    describe "leads_not_dialed" do

      it "should consider not dialed ringing read to dial" do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:voter, campaign: @campaign, status: 'not called')
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
        voter4 = create(:voter, campaign: @campaign, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
        voter5 = create(:voter, campaign: @campaign, :status => CallAttempt::Status::ABANDONED)
        voter6 = create(:voter, campaign: @campaign, status: CallAttempt::Status::READY)
        voter7 = create(:voter, campaign: @campaign, status: CallAttempt::Status::RINGING)
        from_date = @campaign.try(:created_at).in_time_zone(ActiveSupport::TimeZone.new("UTC")).beginning_of_day.to_s
        to_date = Time.now.in_time_zone(ActiveSupport::TimeZone.new("UTC")).end_of_day.to_s
        dial_report = DialReport.new
        dial_report.compute_campaign_report(@campaign, from_date, to_date)
        dial_report.leads_not_dialed.should eq(3)
      end

    end

  end
end
