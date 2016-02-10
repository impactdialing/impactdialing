require 'rails_helper'

describe CallStats::Summary, reports: true do
  include ApplicationHelper::TimeUtils

  describe "dials summary" do
    describe '#retrying' do
      let(:campaign){ create(:predictive, recycle_rate: 1) }
      let(:dial_queue){ campaign.dial_queue }
      let(:retrying){ 3 }

      it 'completed, abandoned and hangup calls are included in the count' do
        allow(dial_queue.available).to receive(:count).with(:active, "(#{campaign.household_sequence + 1}", '+inf'){ retrying }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.retrying).to eq(retrying)
      end
    end

    describe '#pending_retry' do
      let(:campaign){ create(:predictive) }
      let(:dial_queue){ campaign.dial_queue }
      let(:pending_retry){ 42 }

      it 'considers the remaining as available for retry' do
        allow(dial_queue.recycle_bin).to receive(:count){ pending_retry }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.pending_retry).to eq pending_retry
      end
    end

    describe 'not_dialed' do
      let(:campaign){ create(:predictive) }
      let(:dial_queue){ campaign.dial_queue }
      let(:not_dialed){ 12 }

      it 'counts Households that have not been presented (dialed or skipped)' do
        allow(dial_queue.available).to receive(:count).with(:active, '-inf', campaign.household_sequence + 1){ not_dialed }

        dial_report = CallStats::Summary.new(campaign)
        expect(dial_report.not_dialed).to eq(not_dialed)
      end
    end

    describe 'total numbers not currently available to dial' do
      let(:campaign){ create(:predictive) }
      let(:dial_report){ CallStats::Summary.new(campaign) }

      it 'counts households blocked by dnc/cell, completed households & recently dialed households awaiting recycle rate expiry' do
        allow(campaign.dial_queue.blocked).to receive(:count){ 3 }
        allow(dial_report).to receive(:completed){ 7 }
        allow(dial_report).to receive(:pending_retry){ 5 }

        expect(dial_report.total_households_not_to_dial).to eq 15
      end
    end

    describe 'total' do
      include FakeCallData

      let(:admin){ create(:user) }
      let(:account){ admin.account }
      let(:campaign){ create(:campaign, account: account) }
      let(:dial_queue){ campaign.dial_queue }

      def summary(campaign)
        CallStats::Summary.new(campaign)
      end

      describe 'households' do
        let(:total_households){ 42 }

        before do
          allow(dial_queue.available).to receive(:count).with(:active, '-inf', campaign.household_sequence + 1){ 5 }
          allow(dial_queue.available).to receive(:count).with(:active, "(#{campaign.household_sequence + 1}", '+inf'){ 7 }
          allow(dial_queue.blocked).to receive(:count){ 5 }
          allow(dial_queue.completed).to receive(:count).with(:completed, '-inf', '+inf'){ 3 }
          allow(dial_queue.completed).to receive(:count).with(:failed, '-inf', '+inf'){ 2 }
          allow(dial_queue.recycle_bin).to receive(:count){ 20 }
        end
        it 'are loaded from redis (Campaign#call_list.stats[:total_numbers]' do
          expect(summary(campaign).total_households).to eq total_households
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
      let(:completed){ 3 }
      let(:failed){ 2 }
      let!(:other_households) do
        create_list(:voter, available + pending_retry, campaign: campaign, account: account).map(&:household)
      end

      before do
        allow(dial_queue.available).to receive(:count).with(:active, '-inf', campaign.household_sequence + 1){ not_dialed }
        allow(dial_queue.available).to receive(:count).with(:active, "(#{campaign.household_sequence + 1}", '+inf'){ retrying }
        allow(dial_queue.completed).to receive(:count).with(:completed, '-inf', '+inf'){ completed }
        allow(dial_queue.completed).to receive(:count).with(:failed, '-inf', '+inf'){ failed }
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
        summary = CallStats::Summary.new(campaign)
        expect(summary.completed).to eq(completed + failed)
      end
    end
  end
end
