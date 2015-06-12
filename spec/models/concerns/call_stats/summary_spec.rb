require 'rails_helper'

describe CallStats::Summary do
  include ApplicationHelper::TimeUtils

  before do
    Redis.new.flushall
  end

  # * Available to dial
  #   * Not dialed: count of phone numbers not dialed
  #   * Retrying: count of numbers dialed that have voters w/ call_back=true or status='not called'
  # * Not available to dial
  #   * Completed: count of phones where all voters have status!='not called' and call_back=false
  #   * Pending retry: count of phones presented recently and have voters w/ call_back=true or status='not called'
  #   * Phones blocked by Do Not Call list
  #   * Cell phones scrubbed
  # * Total

  describe "dials summary" do
    describe "Completed vs Retry" do
      let(:campaign){ create(:predictive) }
      let(:dial_report){ CallStats::Summary.new(campaign) }
      before do
        create_list(:voter, 10, {campaign: campaign})

        voters = Voter.all
        # 1 of 2 voters dispositioned, this household is not completed
        voters[1].update_attributes!({
          household_id: voters[0].household_id,
          status:       CallAttempt::Status::SUCCESS
        })
        voters[0].household.update_attributes!({
          status:       CallAttempt::Status::SUCCESS,
          presented_at: 5.minutes.ago
        })
        # 2 of 2 voters dispositioned, this household is completed
        voters[3].update_attributes!({
          household_id: voters[2].household_id,
          status:       CallAttempt::Status::SUCCESS
        })
        voters[2].update_attributes!({
          status: CallAttempt::Status::SUCCESS
        })
        voters[2].household.update_attributes!({
          status:       CallAttempt::Status::SUCCESS,
          presented_at: 1.minute.ago
        })
        # dial failed, this household is completed
        voters[4].household.update_attributes!({
          status: CallAttempt::Status::FAILED
        })
      end

      it "count of phones that will not be dialed again: all associated voters have status of CallAttempt::Status::SUCCESS and call_back is false OR the last dial to the household failed" do
        expect(dial_report.households_completely_dispositioned).to eq(2)
      end

      it 'count of phones that have been dialed and have at least one lead that has not been called or needs called back' do
        voters = Voter.all
        voters[5].update_attributes!({
          call_back: true,
          status: CallAttempt::Status::SUCCESS
        })
        voters[5].household.update_attributes!({
          presented_at: 30.seconds.ago,
          status: CallAttempt::Status::SUCCESS
        })
        expect(dial_report.dialed_and_pending_retry).to eq(2)
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

    describe "households_not_dialed_count" do
      it "counts Households w/ blank last_call_attempt_time and w/ statuses not in 'ringing', 'ready' or 'in-progress'" do
        @campaign = create(:predictive, recycle_rate: 3)
        attrs = {campaign: @campaign}
        create(:household, attrs)
        create(:household, :success, attrs.merge(presented_at: 8.minutes.ago))
        create(:household, :hangup, attrs.merge(presented_at: 4.minutes.ago))
        create(:household, :abandoned, attrs.merge(presented_at: 3.minutes.ago))

        dial_report = CallStats::Summary.new(@campaign)

        expect(dial_report.households_not_dialed_count).to eq(1)
      end
    end

    describe 'total numbers not currently available to dial' do
      let(:campaign){ create(:predictive) }
      let(:dial_report){ CallStats::Summary.new(campaign) }

      before do
        allow(dial_report).to receive(:households_blocked_by_dnc){ 2 }
        allow(dial_report).to receive(:households_blocked_by_cell){ 1 }
        allow(dial_report).to receive(:households_completely_dispositioned){ 7 }
        allow(dial_report).to receive(:dialed_and_pending_retry){ 5 }
      end

      it 'counts households blocked by dnc/cell, completed households & recently dialed households awaiting recycle rate expiry' do
        expect(dial_report.total_households_not_to_dial).to eq 15
      end
    end

    describe 'total' do
      include FakeCallData

      let(:admin){ create(:user) }
      let(:account){ admin.account }

      def summary(campaign)
        CallStats::Summary.new(campaign)
      end

      before do
        @campaign = create_campaign_with_script(:bare_predictive, account).last
        all_attrs = {campaign: @campaign, account: account}
        attrs     = all_attrs.merge(presented_at: 5.minutes.ago)

        create_list(:household, 5, :busy, :cell, attrs)
        create_list(:household, 5, :success, :dnc, attrs)
        @dialed_and_blocked_total = 10

        create_list(:household, 5, attrs)
        @not_dialed_and_not_blocked_total = 5

        create_list(:household, 5, :cell, attrs)
        create_list(:household, 5, :dnc, attrs)
        @not_dialed_and_blocked_total = 10

        @total_households = @dialed_and_blocked_total + @not_dialed_and_not_blocked_total + @not_dialed_and_blocked_total
      end

      describe 'households' do
        it 'counts dialed households that have been blocked' do
          expect(summary(@campaign).total_households).to eq @total_households
        end

        it 'counts all households that are not currently blocked' do
          expect(summary(@campaign).total_households).to eq @total_households
        end

        it 'does not count blocked and not dialed households' do
          expect(summary(@campaign).total_households).to eq @total_households
        end
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

        @blocked_and_completed = create_list(:household, 5, :success, attrs.merge({blocked: [:cell]}))
        @blocked_and_completed.each{|h| create(:voter, :success, all_attrs.merge(household: h))}
        @blocked_and_busy      = create_list(:household, 5, :busy, attrs.merge({blocked: [:dnc]}))

        attrs.merge!(presented_at: nil)
        @not_dialed         = create_list(:household, 5, attrs)
        @not_dialed.each{|h| create(:voter, all_attrs.merge(household: h))}
        @not_dialed_blocked = create_list(:household, 5, attrs.merge({blocked: [:cell]}))
        @not_dialed_blocked.each{|h| create(:voter, all_attrs.merge(household: h))}
        @not_dialed        += @not_dialed_blocked

        @blocked_and_not_dialed = create_list(:household, 5, attrs.merge({blocked: [:cell]}))
        @blocked_and_not_dialed += create_list(:household, 5, attrs.merge({blocked: [:dnc]}))

        @dialed = @completed + @available + @not_available[5..-1] # 5 voicemail in both completed & not_available
      end

      it 'includes active (not blocked) not dialed numbers' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.households_not_dialed_count).to eq (@not_dialed.count - @not_dialed_blocked.count)
      end

      it 'dialed' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_count).to eq (@dialed.count + @blocked_and_completed.count + @blocked_and_busy.count)
      end

      it 'not dialed + dialed = all voters' do
        summary  = CallStats::Summary.new(@campaign)
        actual   = summary.households_not_dialed_count + summary.dialed_count
        expected = @campaign.households.active.not_dialed.count + @campaign.households.dialed.count
        expect( actual ).to eq expected
      end

      it 'available' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_and_available_for_retry_count).to eq(@available.count)
      end

      it 'not available' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.dialed_and_not_available_for_retry_count).to eq(@not_available.count + @completed.count - 5 + @blocked_and_busy.count + @blocked_and_completed.count) # 5 voicemail
      end

      it 'completed' do
        summary = CallStats::Summary.new(@campaign)
        expect(summary.households_completely_dispositioned).to eq(40)
        # 20 success/fails, 15 voicemails, 5 success+blocked
      end
    end
  end
end
