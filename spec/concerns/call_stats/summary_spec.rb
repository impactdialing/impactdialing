require "spec_helper"

describe CallStats::Summary do
  include ApplicationHelper::TimeUtils

  before do
    Redis.new.flushall
  end

  describe "overview" do

    describe "completed_voters_count" do

      it "returns count indicating number of voters that were successfully dispositioned" do
        @campaign     = create(:predictive)
        voter1        = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2        = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter3        = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4        = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1, household: voter1.household)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter2, household: voter2.household)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3, household: voter3.household)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4, household: voter4.household)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.completed_voters_count).to eq(2)
      end

      it "should include all failed call attempts" do
        @campaign     = create(:predictive)
        voter1        = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter2        = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3        = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4        = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter1)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.completed_voters_count).to eq(2)
      end

      it "should include all successful failed call attempts" do
        @campaign = create(:predictive)
        voter1 = create(:voter, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now)
        voter2 = create(:voter, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now)
        voter3 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        voter4 = create(:voter, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now)
        call_attempt1 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::SUCCESS, created_at: Time.now, voter: voter1)
        call_attempt2 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::FAILED, created_at: Time.now, voter: voter2)
        call_attempt3 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter3)
        call_attempt4 = create(:call_attempt, campaign: @campaign, status: CallAttempt::Status::BUSY, created_at: Time.now, voter: voter4)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.completed_voters_count).to eq(2)
      end
    end

    describe "dialed_and_available_for_retry_count" do

      it "should consider available and abandoned calls" do
        @campaign = create(:predictive, recycle_rate: 1)

        create(:household, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        create(:household, campaign: @campaign, status: CallAttempt::Status::SUCCESS)
        create(:household, campaign: @campaign, presented_at: 2.hours.ago, status: CallAttempt::Status::HANGUP)
        create(:household, campaign: @campaign, presented_at: 3.hours.ago, status: CallAttempt::Status::ABANDONED)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.dialed_and_available_for_retry_count).to eq(2)
      end
    end

    describe "dialed_and_not_available_for_retry_count" do

      before do
        @campaign = create(:predictive, recycle_rate: 3)

        voter1 = create(:voter, :success, :recently_dialed, campaign: @campaign)
        voter1.household.update_attributes!(presented_at: 5.minutes.ago, status: CallAttempt::Status::SUCCESS)

        voter2 = create(:voter, :success, :recently_dialed, campaign: @campaign)
        voter2.household.update_attributes!(presented_at: 5.minutes.ago, status: CallAttempt::Status::SUCCESS)

        house3 = create(:household, campaign: @campaign, presented_at: 5.minutes.ago, status: CallAttempt::Status::HANGUP)
        house4 = create(:household, campaign: @campaign, presented_at: 5.minutes.ago, status: CallAttempt::Status::HANGUP)
        house5 = create(:household, campaign: @campaign, presented_at: (@campaign.recycle_rate + 1).hours.ago, status: CallAttempt::Status::ABANDONED)

        @dial_report = CallStats::Summary.new(@campaign)
      end

      it "returns count of voters who may be retried but are not currently available (dialed & not available)" do
        expect(@dial_report.dialed_and_not_available_for_retry_count).to eq 4
      end

      it 'considers the remaining as available for retry' do
        expect(@dial_report.dialed_and_available_for_retry_count).to eq 1
      end
    end

    describe "leads_not_dialed" do

      it "counts Voters w/ blank last_call_attempt_time and w/ statuses not in 'ringing', 'ready' or 'in-progress'" do
        @campaign = create(:predictive, recycle_rate: 3)
        voter1 = create(:voter, campaign: @campaign, status: 'not called')
        voter2 = create(:voter, :success, :not_recently_dialed, campaign: @campaign)
        voter3 = create(:voter, :hangup, :not_recently_dialed, campaign: @campaign)
        voter5 = create(:voter, :abandoned, :not_recently_dialed, campaign: @campaign)
        voter6 = create(:voter, :queued, campaign: @campaign)
        voter7 = create(:voter, :ringing, :recently_dialed, campaign: @campaign)

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.not_dialed_count).to eq(1)
      end

    end

    describe 'the math' do
      include FakeCallData

      let(:admin){ create(:user) }
      let(:account){ admin.account }

      before do
        @campaign = create_campaign_with_script(:bare_predictive, account).last
        all_attrs = {campaign: @campaign, account: account}
        attrs     = all_attrs.merge(presented_at: 5.minutes.ago)

        @completed =  create_list(:voter, 5, :success, all_attrs)
        @completed += create_list(:voter, 5, :failed, all_attrs)
        @completed += create_list(:voter, 5, :success, all_attrs)
        @completed += create_list(:voter, 5, :failed, all_attrs)
        @completed.each{|v| v.household.update_attributes!(status: v.status)}

        attrs.merge!(presented_at: (@campaign.recycle_rate + 1).hours.ago)
        @available =  create_list(:household, 5, :busy, attrs)
        @available += create_list(:household, 5, :abandoned, attrs)
        @available += create_list(:household, 5, :no_answer, attrs)
        @available += create_list(:household, 5, :hangup, attrs)
        
        # 5 voicemails (campaign does not call back after voicemail)
        @not_available = create_list(:household, 5, :voicemail, attrs)
        @completed    += @not_available.map{|h| create(:voter, :voicemail, all_attrs.merge(household: h))}

        attrs.merge!(presented_at: 5.minutes.ago)
        @not_available += create_list(:household, 5, :busy, attrs)
        @not_available += create_list(:household, 5, :abandoned, attrs)
        @not_available += create_list(:household, 5, :no_answer, attrs)
        @not_available += create_list(:household, 5, :voicemail, attrs)
        @not_available += create_list(:household, 5, :hangup, attrs)
        @not_available += create_list(:household, 5, :voicemail, attrs)

        attrs.merge!(presented_at: nil)
        @not_dialed = create_list(:household, 5, attrs)

        @dialed = @completed + @available + @not_available[5..-1] # 5 voicemail in both completed & not_available
      end

      it 'not dialed' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.not_dialed_count).to eq @not_dialed.count
      end

      it 'dialed' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_count).to eq @dialed.count
      end

      it 'not dialed + dialed = all voters' do
        summary = CallStats::Summary.new(@campaign)
        expect( summary.not_dialed_count + summary.dialed_count ).to eq @campaign.households.count
      end

      it 'available' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_and_available_for_retry_count).to eq(@available.count)
      end

      it 'not available' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_and_not_available_for_retry_count).to eq(@not_available.count + @completed.count - 5) # 5 voicemail
      end

      it 'completed' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.completed_voters_count).to eq(@completed.count)
      end
    end
  end
end
