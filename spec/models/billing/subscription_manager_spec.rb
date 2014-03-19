require 'spec_helper'

describe Billing::SubscriptionManager do
  describe '#prorate?(new_plan, callers_allowed)' do
    let(:customer_id){ 'cus_243fij0wije' }
    let(:old_plan){ 'trial' }
    let(:new_plan){ 'basic' }
    let(:callers_allowed){ 1 }
    let(:opts) do
      {
        callers_allowed: callers_allowed
      }
    end

    let(:subscription) do
      mock_model(Billing::Subscription, {
        plan: 'trial',
        plan_changed!: nil
      })
    end
    let(:quota) do
      mock_model(Quota, {
        callers_allowed: callers_allowed,
        minutes_available?: true,
        plan_changed!: nil
      })
    end
    let(:payment_gateway) do
      double('PaymentGatewayFake', {
        update_subscription: double('StripeSubscription'),
        create_charge: double('StripeCharge'),
        create_and_pay_invoice: double('StripeInvoice'),
        cancel_subscription: nil
      })
    end
    let(:plans) do
      double('Billing::Plans', {
        validate_transition!: true
      })
    end
    let(:manager) do
      Billing::SubscriptionManager.new(customer_id, subscription, quota)
    end

    def new_manager(subscription, quota)
      Billing::SubscriptionManager.new(customer_id, subscription, quota)
    end

    context 'upgrading from trial to anything' do
      it 'is not pro-rated' do
        ['basic', 'pro', 'business', 'per_minute'].each do |new_plan_id|
          manager.prorate?(new_plan_id, 1).should be_false
        end
      end
    end
    context 'upgrading to per minute from anything' do
      it 'is never pro-rated' do
        ['trial', 'basic', 'pro', 'business'].each do |old_plan_id|
          subscription.stub(:plan){ old_plan_id }
          manager = new_manager(subscription, quota)
          manager.prorate?('per_minute').should be_false
        end
      end
    end
    context 'upgrading from recurring plans to recurring plans' do
      let(:plan_ids) do
        [
          ['basic', 'pro'],
          ['pro', 'business'],
          ['basic', 'business']
        ]
      end
      it 'is pro-rated' do
        plan_ids.each do |set|
          subscription.stub(:plan){ set[0] }
          manager = new_manager(subscription, quota)
          manager.prorate?(set[1], 1).should be_true
        end
      end
      it 'even when reducing callers' do
        plan_ids.each do |set|
          subscription.stub(:plan){set[0]}
          quota.stub(:callers_allowed){5}
          manager = new_manager(subscription, quota)
          manager.prorate?(set[1], 3).should be_true
        end
      end
    end
    context 'adding callers to the same recurring plan' do
      it 'is pro-rated' do
        ['basic', 'pro', 'business'].each do |id|
          subscription.stub(:plan){ id }
          quota.stub(:callers_allowed){3}
          manager = new_manager(subscription, quota)
          manager.prorate?(id, 5).should be_true
        end
      end
    end
  end

  describe '#update!(new_plan, opts)', lint: true do
    let(:customer_id){ 'cus_243fij0wije' }
    let(:old_plan){ 'trial' }
    let(:new_plan){ 'basic' }
    let(:callers_allowed){ 1 }
    let(:opts) do
      {
        callers_allowed: callers_allowed
      }
    end

    let(:subscription) do
      mock_model(Billing::Subscription, {
        plan: 'trial',
        plan_changed!: nil
      })
    end
    let(:quota) do
      mock_model(Quota, {
        callers_allowed: callers_allowed,
        minutes_available?: true,
        plan_changed!: nil
      })
    end
    let(:payment_gateway) do
      double('PaymentGatewayFake', {
        update_subscription: double('StripeSubscription'),
        create_charge: double('StripeCharge'),
        create_and_pay_invoice: double('StripeInvoice'),
        cancel_subscription: nil
      })
    end
    let(:plans) do
      double('Billing::Plans', {
        validate_transition!: true
      })
    end
    let(:manager) do
      Billing::SubscriptionManager.new(customer_id, subscription, quota)
    end

    before do
      plans.stub(:recurring?){ true }
      plans.stub(:is_trial?){ true }
      plans.stub(:buying_minutes?){ false }
      Billing::PaymentGateway.stub(:new){ payment_gateway }
      Billing::Plans.stub(:new){ plans }
    end

    it 'tells `plans` to validate the transition' do
      plans.should_receive(:validate_transition!).with(old_plan, new_plan, quota.minutes_available?, opts)
      manager.update!(new_plan, opts)
    end
    context 'plans.recurring? => true' do
      it 'tells `payment_gateway` to update the subscription' do
        payment_gateway.should_receive(:update_subscription).with(new_plan, callers_allowed, anything)
        manager.update!(new_plan, opts)
      end
      context 'old_plan is not trial AND this is an upgrade in plans OR addition of callers' do
        let(:new_plan){ 'pro' }
        before do
          plans.stub(:is_trial?){ false }
          plans.stub(:is_upgrade?){ true }
          plans.stub(:buying_minutes?){ false }
          subscription.stub(:plan){ 'basic' }
        end
        it 'tells `payment_gateway` to prorate upgrades' do
          payment_gateway.should_receive(:update_subscription).with(new_plan, callers_allowed, true)
          manager.update!(new_plan, opts)
        end
        it 'tells `payment_gateway` to prorate increase in number of callers allowed' do
          subscription.plan.should eq 'basic'
          payment_gateway.should_receive(:update_subscription).with('basic', callers_allowed + 1, true)
          manager.update!('basic', {callers_allowed: callers_allowed + 1})
        end
        it 'tells `payment_gateway` to create and pay an invoice' do
          payment_gateway.should_receive(:create_and_pay_invoice)
          manager.update!(new_plan, opts)
        end
      end
      context 'old_plan is trial OR this is a downgrade in plans' do
        before do
          plans.stub(:is_trial?){ true }
          plans.stub(:is_upgrade?){ false }
          plans.stub(:buying_minutes?){ false }
          subscription.stub(:plan){ 'trial' }
        end
        it 'tells `payment_gateway` to NOT prorate the subscription change (old_plan is a trial)' do
          payment_gateway.should_receive(:update_subscription).with(new_plan, callers_allowed, false)
          manager.update!(new_plan, opts)
        end

        it 'tells `payment_gateway` to NOT prorate the subscription change (old_plan is pro, new is basic)' do
          subscription.stub(:plan){ 'pro' }
          new_plan = 'basic'
          payment_gateway.should_receive(:update_subscription).with(new_plan, callers_allowed, false)
          manager.update!(new_plan, opts)
        end

        it 'does NOT tell `payment_gateway` to create and pay an invoice' do
          payment_gateway.should_not_receive(:create_and_pay_invoice)
          manager.update!(new_plan, opts)
        end
      end
    end
    context 'plans.recurring? => false' do
      let(:valid_amount_paid){ 12 }
      before do
        plans.stub(:recurring?){ false }
      end
      it 'tells `payment_gateway` to create a charge' do
        subscription.stub(:plan){ 'trial' }
        payment_gateway.should_receive(:create_charge).with(valid_amount_paid)
        manager.update!('per_minute', {amount_paid: valid_amount_paid})
      end
    end
  end
end
