require 'spec_helper'

describe Billing::Subscription do
  let(:valid_settings) do
    {enabled: 1, amount: 3, trigger: 5, pending: 0}
  end
  let(:subscription){ Billing::Subscription.new }

  describe ':settings' do
    it 'is serialized as HashWithIndifferentAccess' do
      subscription.settings.should be_kind_of HashWithIndifferentAccess
    end

    describe 'autorecharge_settings' do
      it 'has an :enabled key' do
        subscription.autorecharge_settings.should have_key :enabled
      end
      it 'has an :amount key' do
        subscription.autorecharge_settings.should have_key :amount
      end
      it 'has a :trigger key' do
        subscription.autorecharge_settings.should have_key :trigger
      end
      it 'has a :pending key' do
        subscription.autorecharge_settings.should have_key :pending
      end
      it 'defaults to disabled' do
        subscription.autorecharge_settings[:enabled].should eq 0
      end
    end

    describe '#update_autorecharge_settings!(new_settings)' do
      let(:account){ create(:account) }
      let(:subscription){ account.billing_subscription }
      it 'raises ActiveRecord::RecordInvalid if the new settings are invalid' do
        invalid_settings = {enabled: 1, amount: 0, trigger: 0}
        expect{
          subscription.update_autorecharge_settings!(invalid_settings)
        }.to raise_error ActiveRecord::RecordInvalid
      end
      it 'merges the current autorecharge hash w/ new_settings' do
        valid_settings = {'enabled' => 1, 'amount' => 1, 'trigger' => 1}
        subscription.update_autorecharge_settings!(valid_settings)
        subscription.reload
        subscription.autorecharge_settings.should eq valid_settings
      end
    end

    describe '#autorecharge_amount' do
      let(:account){ create(:account) }
      let(:subscription){ account.billing_subscription }
      it 'returns an Integer' do
        subscription.update_autorecharge_settings!(valid_settings)
        subscription.autorecharge_amount.should eql 3
      end
    end

    describe '#autorecharge_pending!' do
      let(:account){ create(:account) }
      let(:subscription){ account.billing_subscription }
      before do
        subscription.autorecharge_pending?.should be_false
        subscription.autorecharge_pending!
      end
      it 'save! autorecharge_pending as 1' do
        subscription.reload.autorecharge_pending.should eql 1
      end
    end

    describe '#is_renewal?(start_period, end_period)' do
      let(:subscription){ Billing::Subscription.new }
      let(:start_period){ Time.at(10.minutes.ago) }
      let(:end_period){ Time.at(start_period + 1.month) }

      context 'start_period > self.provider_start_period and end_period > self.provider_end_period' do
        before do
          subscription.provider_start_period = Time.at(start_period - 1.month)
          subscription.provider_end_period   = Time.at(end_period - 1.month)
        end

        it 'returns true' do
          subscription.is_renewal?(start_period, end_period).should be_true
        end
      end

      context 'start_period <= self.provider_start_period or end_period <= self.provider_end_period' do
        before do
          subscription.provider_start_period = start_period
          subscription.provider_end_period   = end_period
        end
        it 'returns false' do
          subscription.is_renewal?(start_period, end_period).should be_false
        end
      end
    end

    describe '#renewed!(start_period, end_period, status)' do
      let(:account){ create(:account) }
      let(:subscription){ account.billing_subscription }
      let(:start_period){ Time.at(10.minutes.ago) }
      let(:end_period){ Time.at(start_period + 1.month) }
      let(:status){ 'active' }

      it 'sets provider_start_period to start_period' do
        subscription.renewed!(start_period, end_period, status)
        actual = Time.at(subscription.reload.provider_start_period).utc
        expected = start_period.utc
        actual.should be_within(1).of(expected)
      end
      it 'sets provider_end_period to end_period' do
        subscription.renewed!(start_period, end_period, status)
        actual = Time.at(subscription.reload.provider_end_period).utc
        expected = end_period.utc
        actual.should be_within(1).of(expected)
      end
      context 'when invalid' do
        it 'raises ActiveRecord::RecordInvalid' do
          subscription.plan = nil
          expect {
            subscription.renewed!(start_period, end_period, status)
          }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    describe '#cache_provider_status!(status)' do
      let(:account){ create(:account) }
      let(:subscription){ account.billing_subscription }
      let(:status){ 'past_due' }

      it 'sets provider_status to status' do
        subscription.cache_provider_status!(status)
        subscription.provider_status.should eq status
      end
      context 'when invalid' do
        it 'raises ActiveRecord::RecordInvalid' do
          subscription.plan = nil
          expect {
            subscription.cache_provider_status!(status)
          }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end
end
