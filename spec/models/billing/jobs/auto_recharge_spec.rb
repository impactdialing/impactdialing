require 'spec_helper'

describe Billing::Jobs::AutoRecharge do
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
      available_minutes: 200
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
    Account.stub(:find).with(account_id){ account }
    Billing::SubscriptionManager.stub(:new).with(customer_id, subscription, quota){ subscription_manager }
  end

  shared_examples "no recharge needed" do
    after do
      subject.perform(account_id)
    end
    it 'tells billing_subscription_manager nothing' do
      Billing::SubscriptionManager.should_not_receive(:new)
      subscription_manager.should_not_receive(:update!)
    end
  end

  context 'quota.available_minutes < autorecharge_trigger && not autorecharge_pending?' do
    before do
      quota.stub(:available_minutes){ subscription.autorecharge_trigger - 4 }
    end
    after do
      subject.perform(account_id)
    end
    it 'tells billing_subscription_manager update!(plan_id, {amount_paid: amount})' do
      subscription_manager.should_receive(:update!).with('per_minute', {amount_paid: amount, autorecharge: anything})
    end
  end
  context 'quota.available_minutes < autorecharge_trigger || autorecharge_pending?' do
    it_behaves_like 'no recharge needed'
  end
  context 'subscription.plan != per_minute' do
    before do
      quota.stub(:available_minutes){ subscription.autorecharge_trigger - 4 }
      subscription.stub(:plan){ 'business' }
    end
    it_behaves_like 'no recharge needed'
  end
end