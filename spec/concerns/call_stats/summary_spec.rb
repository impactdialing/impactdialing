require "spec_helper"

describe CallStats::Summary do
  include ApplicationHelper::TimeUtils

  describe "overview" do

    describe "dialed_and_complete_count" do

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

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
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

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
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

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_complete_count).to eq(2)
      end
    end

    describe "dialed_and_available_for_retry_count" do

      it "should consider available and abandoned calls" do
        @campaign = create(:predictive, recycle_rate: 1)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: 2.hours.ago)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::HANGUP)
        voter5 = create(:voter, campaign: @campaign, last_call_attempt_time: 3.hours.ago, status: CallAttempt::Status::ABANDONED)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_available_for_retry_count).to eq(2)
      end
    end

    describe "dialed_and_not_available_for_retry_count" do

      before do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, last_call_attempt_time: Time.now - 2.hours)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: 2.hours.ago, status: CallAttempt::Status::HANGUP)
        voter4 = create(:voter, campaign: @campaign, last_call_attempt_time: 1.hours.ago, status: CallAttempt::Status::HANGUP)
        voter7 = create(:voter, campaign: @campaign, last_call_attempt_time: 4.hours.ago, status: CallAttempt::Status::ABANDONED)
        @dial_report = CallStats::Summary.new(@campaign)
      end

      it "should consider not available for retry now" do
        expect(@dial_report.dialed_and_not_available_for_retry_count).to eq 4
      end

      it 'considers the remaining as available for retry' do
        expect(@dial_report.dialed_and_available_for_retry_count).to eq 1
      end
    end

    describe "leads_not_dialed" do

      it "should consider not dialed, ringing & ready to dial" do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:voter, campaign: @campaign, status: 'not called')
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        voter3 = create(:voter, campaign: @campaign, last_call_attempt_time: Time.now - 2.hours, status: CallAttempt::Status::HANGUP)
        voter4 = create(:voter, campaign: @campaign, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
        voter5 = create(:voter, campaign: @campaign, :status => CallAttempt::Status::ABANDONED)
        voter6 = create(:voter, campaign: @campaign, status: CallAttempt::Status::READY)
        voter7 = create(:voter, campaign: @campaign, status: CallAttempt::Status::RINGING)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.not_dialed_count).to eq(3)
      end

    end

  end
end
