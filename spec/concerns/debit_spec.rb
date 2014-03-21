require 'spec_helper'

describe Debit do
  let(:call_time) do
    mock_model('CallTime', {
      :debited => false,
      :debited= => nil,
      :tDuration => nil,
      :tStartTime => nil,
      :tEndTime => nil
    })
  end
  let(:subscription) do
    double('Billing::Subscription', {
      autorecharge_trigger: 100,
      autorecharge_pending?: false,
      autorecharge_active?: false
    })
  end
  let(:quota) do
    mock_model('Quota', {
      debit: nil,
      minutes_available: subscription.autorecharge_trigger + 5
    })
  end
  let(:account) do
    mock_model('Account', {
      quota: quota,
      billing_subscription: subscription
    })
  end

  describe "#process" do
    let(:debit){ Debit.new(call_time, quota, account) }
    before do
      call_time.stub(:tStartTime){ 20.minutes.ago }
      call_time.stub(:tEndTime){ 15.minutes.ago }
      call_time.stub(:tDuration){ 5 * 60 }
    end

    it 'debits the call_time tDuration in minutes from quota' do
      quota.should_receive(:debit).with(5){ true }
      call_time.should_receive(:debited=).with(true)
      debit.process
    end

    context 'recharge_needed? => true' do
      before do
        subscription.stub(:autorecharge_active?){ true }
        quota.stub(:minutes_available){ subscription.autorecharge_trigger - 1 }
        @debit = Debit.new(call_time, quota, account)
      end

      it 'queues Billing::Jobs::AutoRecharge(account.id)' do
        Resque.should_receive(:enqueue).with(Billing::Jobs::AutoRecharge, account.id)
        @debit.process
      end
    end

    it 'returns the call_time object' do
      debit.process.should eq call_time
    end
  end
end
