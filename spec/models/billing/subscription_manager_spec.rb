require 'spec_helper'

describe Billing::SubscriptionManager do
  describe '#update!(new_plan, opts)' do
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
        plan: 'trial'
      })
    end
    let(:quota) do
      mock_model(Quota, {
        callers_allowed: callers_allowed
      })
    end
    let(:payment_gateway) do
      double('PaymentGatewayFake', {
        update_subscription: double('StripeSubscription'),
        create_charge: double('StripeCharge'),
        create_and_pay_invoice: double('StripeInvoice')
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
      Billing::PaymentGateway.stub(:new){ payment_gateway }
      Billing::Plans.stub(:new){ plans }
    end

    it 'tells `plans` to validate the transition' do
      plans.should_receive(:validate_transition!).with(old_plan, new_plan, opts)
      manager.update!(new_plan, opts)
    end
    context 'plans.recurring? => true' do
      it 'tells `payment_gateway` to update the subscription' do
        payment_gateway.should_receive(:update_subscription).with(new_plan, callers_allowed, anything)
        manager.update!(new_plan, opts)
      end
      context 'old_plan is not trial AND this is an upgrade in plans OR change to existing plan' do
        let(:new_plan){ 'pro' }
        before do
          plans.stub(:is_trial?){ false }
          plans.stub(:is_upgrade?){ true }
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
