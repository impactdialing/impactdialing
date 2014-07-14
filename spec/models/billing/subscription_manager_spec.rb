require 'spec_helper'

describe Billing::SubscriptionManager, :type => :model do
  def new_manager(subscription, quota)
    Billing::SubscriptionManager.new(customer_id, subscription, quota)
  end

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

    context 'upgrading from trial to anything' do
      it 'is not pro-rated' do
        ['basic', 'pro', 'business', 'per_minute'].each do |new_plan_id|
          expect(manager.prorate?(new_plan_id, 1)).to be_falsey
        end
      end
    end
    context 'upgrading to per minute from anything' do
      it 'is never pro-rated' do
        ['trial', 'basic', 'pro', 'business'].each do |old_plan_id|
          allow(subscription).to receive(:plan){ old_plan_id }
          manager = new_manager(subscription, quota)
          expect(manager.prorate?('per_minute')).to be_falsey
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
          allow(subscription).to receive(:plan){ set[0] }
          manager = new_manager(subscription, quota)
          expect(manager.prorate?(set[1], 1)).to be_truthy
        end
      end
      it 'even when reducing callers' do
        plan_ids.each do |set|
          allow(subscription).to receive(:plan){set[0]}
          allow(quota).to receive(:callers_allowed){5}
          manager = new_manager(subscription, quota)
          expect(manager.prorate?(set[1], 3)).to be_truthy
        end
      end
    end
    context 'adding callers to the same recurring plan' do
      it 'is pro-rated' do
        ['basic', 'pro', 'business'].each do |id|
          allow(subscription).to receive(:plan){ id }
          allow(quota).to receive(:callers_allowed){3}
          manager = new_manager(subscription, quota)
          expect(manager.prorate?(id, 5)).to be_truthy
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
      allow(plans).to receive(:recurring?){ true }
      allow(plans).to receive(:is_trial?){ true }
      allow(plans).to receive(:buying_minutes?){ false }
      allow(Billing::PaymentGateway).to receive(:new){ payment_gateway }
      allow(Billing::Plans).to receive(:new){ plans }
    end

    it 'tells `plans` to validate the transition' do
      expect(plans).to receive(:validate_transition!).with(old_plan, new_plan, quota.minutes_available?, opts)
      manager.update!(new_plan, opts)
    end
    context 'plans.recurring? => true' do
      it 'tells `payment_gateway` to update the subscription' do
        expect(payment_gateway).to receive(:update_subscription).with(new_plan, callers_allowed, anything)
        manager.update!(new_plan, opts)
      end
      context 'old_plan is not trial AND' do
        context 'this is an upgrade in plans OR' do
          let(:new_plan){ 'pro' }
          before do
            allow(plans).to receive(:is_trial?){ false }
            allow(plans).to receive(:is_upgrade?){ true }
            allow(plans).to receive(:buying_minutes?){ false }
            allow(subscription).to receive(:plan){ 'basic' }
          end
          it 'tells `payment_gateway` to prorate upgrades' do
            expect(payment_gateway).to receive(:update_subscription).with(new_plan, callers_allowed, true)
            manager.update!(new_plan, opts)
          end
          it 'tells `payment_gateway` to create and pay an invoice' do
            expect(payment_gateway).to receive(:create_and_pay_invoice)
            manager.update!(new_plan, opts)
          end
        end

        context 'plan is the same w/ addition of callers' do
          let(:new_plan){ 'pro' }
          let(:opts) do
            {callers_allowed: callers_allowed + 1}
          end
          before do
            allow(plans).to receive(:is_trial?){ false }
            allow(plans).to receive(:is_upgrade?){ false }
            allow(plans).to receive(:buying_minutes?){ false }
            allow(subscription).to receive(:plan){ 'pro' }
          end
          it 'tells `payment_gateway` to prorate increase in callers' do
            expect(payment_gateway).to receive(:update_subscription).with('pro', callers_allowed + 1, true)
            manager.update!('pro', opts)
          end
          it 'tells `payment_gateway` to create and pay an invoice' do
            expect(payment_gateway).to receive(:create_and_pay_invoice)
            manager.update!('pro', opts)
          end
        end
      end
      context 'old_plan is trial OR this is a downgrade in plans' do
        before do
          allow(plans).to receive(:is_trial?){ true }
          allow(plans).to receive(:is_upgrade?){ false }
          allow(plans).to receive(:buying_minutes?){ false }
          allow(subscription).to receive(:plan){ 'trial' }
        end
        it 'tells `payment_gateway` to NOT prorate the subscription change (old_plan is a trial)' do
          expect(payment_gateway).to receive(:update_subscription).with(new_plan, callers_allowed, false)
          manager.update!(new_plan, opts)
        end

        it 'tells `payment_gateway` to NOT prorate the subscription change (old_plan is pro, new is basic)' do
          allow(subscription).to receive(:plan){ 'pro' }
          new_plan = 'basic'
          expect(payment_gateway).to receive(:update_subscription).with(new_plan, callers_allowed, false)
          manager.update!(new_plan, opts)
        end

        it 'does NOT tell `payment_gateway` to create and pay an invoice' do
          expect(payment_gateway).not_to receive(:create_and_pay_invoice)
          manager.update!(new_plan, opts)
        end
      end
    end
    context 'plans.recurring? => false' do
      let(:valid_amount_paid){ 12 }
      before do
        allow(plans).to receive(:recurring?){ false }
      end
      it 'tells `payment_gateway` to create a charge' do
        allow(subscription).to receive(:plan){ 'trial' }
        expect(payment_gateway).to receive(:create_charge).with(valid_amount_paid)
        manager.update!('per_minute', {amount_paid: valid_amount_paid})
      end
    end
  end
end
