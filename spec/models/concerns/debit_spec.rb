require 'rails_helper'

describe Debit do
  let(:call_time) do
    double('CallTime', {
      :id => 42,
      :debited => false,
      :debited= => nil,
      :tDuration => nil,
      :tStartTime => nil,
      :tEndTime => nil
    })
  end
  let(:subscription) do
    build(:bare_subscription, {
      settings: {autorecharge: {trigger: 100}}
    })
  end
  let(:quota) do
    build(:bare_quota, {
      minutes_allowed: subscription.autorecharge_trigger + 5
    })
  end
  let(:account) do
    build(:bare_account, {
      quota: quota,
      billing_subscription: subscription
    })
  end

  describe "#process" do
    let(:debit){ Debit.new(call_time, quota, account) }
    before do
      allow(call_time).to receive(:tStartTime){ 20.minutes.ago }
      allow(call_time).to receive(:tEndTime){ 15.minutes.ago }
      allow(call_time).to receive(:tDuration){ 5 * 60 }
    end

    it 'debits the call_time tDuration in minutes from quota' do
      expect(quota).to receive(:debit).with(5){ true }
      expect(call_time).to receive(:debited=).with(true)
      debit.process
    end

    context 'recharge_needed? => true' do
      before do
        allow(subscription).to receive(:autorecharge_active?){ true }
        allow(quota).to receive(:minutes_available){ subscription.autorecharge_trigger - 1 }
        @debit = Debit.new(call_time, quota, account)
      end

      it 'queues Billing::Jobs::AutoRecharge(account.id)' do
        expect(Resque).to receive(:enqueue).with(Billing::Jobs::AutoRecharge, account.id)
        @debit.process
      end
    end

    it 'returns the call_time object' do
      expect(debit.process).to eq call_time
    end
  end
end
