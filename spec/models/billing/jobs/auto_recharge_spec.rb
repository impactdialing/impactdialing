require 'spec_helper'

describe Billing::Jobs::AutoRecharge, :type => :model do
  subject{ Billing::Jobs::AutoRecharge }
  let(:account_id){ 12 }
  let(:customer_id){ 'abc123' }
  let(:plan_id){ 'per_minute' }
  let(:amount){ 9 }
  let(:subscription) do
    double('Subscription', {
      plan: plan_id,
      autorecharge_trigger: 100,
      autorecharge_amount: amount,
      autorecharge_pending?: false,
      autorecharge_pending!: nil
    })
  end
  let(:quota) do
    double('Quota', {
      minutes_available: 200
    })
  end
  let(:account) do
    double('Account', {
      billing_subscription: subscription,
      billing_provider_customer_id: customer_id,
      quota: quota
    })
  end
  let(:subscription_manager) do
    double('Billing::SubscriptionManager', {
      update!: nil
    })
  end

  before do
    allow(Account).to receive(:find).with(account_id){ account }
    allow(Billing::SubscriptionManager).to receive(:new).with(customer_id, subscription, quota){ subscription_manager }
  end

  shared_examples "no recharge needed" do
    after do
      subject.perform(account_id)
    end
    it 'tells billing_subscription_manager nothing' do
      expect(Billing::SubscriptionManager).not_to receive(:new)
      expect(subscription_manager).not_to receive(:update!)
    end
  end

  context 'quota.minutes_available < autorecharge_trigger && not autorecharge_pending?' do
    before do
      allow(quota).to receive(:minutes_available){ subscription.autorecharge_trigger - 4 }
    end
    after do
      subject.perform(account_id)
    end
    it 'tells billing_subscription_manager update!(plan_id, {amount_paid: amount})' do
      expect(subscription_manager).to receive(:update!).with('per_minute', {amount_paid: amount, autorecharge: anything})
    end
  end
  context 'quota.minutes_available < autorecharge_trigger || autorecharge_pending?' do
    it_behaves_like 'no recharge needed'
  end
  context 'subscription.plan != per_minute' do
    before do
      allow(quota).to receive(:minutes_available){ subscription.autorecharge_trigger - 4 }
      allow(subscription).to receive(:plan){ 'business' }
    end
    it_behaves_like 'no recharge needed'
  end
end