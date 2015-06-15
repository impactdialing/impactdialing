require 'rails_helper'

describe CallStats::Summary do
  include ApplicationHelper::TimeUtils

  before do
    Redis.new.flushall
  end

  describe "dials summary" do
    describe '#retrying' do
      let(:campaign){ create(:predictive, recycle_rate: 1) }
      let(:dial_queue){ campaign.dial_queue }
      let(:retrying){ 3 }

      it 'completed, abandoned and hangup calls are included in the count' do
        allow(dial_queue.available).to receive(:count).with(:active, '2.0', '+inf'){ retrying }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.retrying).to eq(retrying)
      end
    end

    describe '#pending_retry' do
      let(:campaign){ create(:predictive) }
      let(:dial_queue){ campaign.dial_queue }
      let(:pending_retry){ 42 }

      it 'considers the remaining as available for retry' do
        allow(dial_queue.recycle_bin).to receive(:size){ pending_retry }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.pending_retry).to eq pending_retry
      end
    end

    describe 'not_dialed' do
      let(:campaign){ create(:predictive) }
      let(:dial_queue){ campaign.dial_queue }
      let(:not_dialed){ 12 }

      it 'counts Households that have not been presented (dialed or skipped)' do
        allow(dial_queue.available).to receive(:count).with(:active, '-inf', '2.0'){ not_dialed }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.not_dialed).to eq(not_dialed)
      end
    end

    describe 'total numbers not currently available to dial' do
      let(:campaign){ create(:predictive) }
      let(:dial_report){ CallStats::Summary.new(campaign) }

      it 'counts households blocked by dnc/cell, completed households & recently dialed households awaiting recycle rate expiry' do
        allow(dial_report).to receive(:households_blocked_by_dnc){ 2 }
        allow(dial_report).to receive(:households_blocked_by_cell){ 1 }
        allow(dial_report).to receive(:completed){ 7 }
        allow(dial_report).to receive(:pending_retry){ 5 }

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
      let(:campaign){ create(:predictive, account: account) }
      let(:dial_queue){ campaign.dial_queue }
      let(:not_dialed){ 5 }
      let(:retrying){ 3 }
      let(:available){ not_dialed + retrying }
      let(:pending_retry){ 2 }
      let!(:completed_households) do
        create_list(:voter, 3, campaign: campaign, account: account).map(&:household)
      end
      let!(:other_households) do
        create_list(:voter, available + pending_retry, campaign: campaign, account: account).map(&:household)
      end

      before do
        allow(dial_queue.available).to receive(:count).with(:active, '-inf', '2.0'){ not_dialed }
        allow(dial_queue.available).to receive(:count).with(:active, '2.0', '+inf'){ retrying }
        allow(dial_queue.available).to receive(:size).with(:active){ available }
        allow(dial_queue.available).to receive(:size).with(:presented){ 0 }
        allow(dial_queue.recycle_bin).to receive(:size){ pending_retry }
      end

      it 'includes active (not blocked) not dialed numbers' do
        summary = CallStats::Summary.new(campaign)
        expect(summary.not_dialed).to eq (not_dialed)
      end

      it 'available' do
        summary = CallStats::Summary.new(campaign)
        expect(summary.retrying).to eq(retrying)
      end

      it 'completed' do
        # byebug
        summary = CallStats::Summary.new(campaign)
        expect(summary.completed).to eq(completed_households.size)
      end
    end
  end
end
