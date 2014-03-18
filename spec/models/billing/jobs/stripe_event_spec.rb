require 'spec_helper'

describe Billing::Jobs::StripeEvent do
  subject{ Billing::Jobs::StripeEvent }

  let(:stripe_event_id){ 'evt_123' }
  let(:stripe_customer_id){ 'cus_321' }
  let(:relation) do
    double('Relation', {
      where: []
    })
  end

  let(:plan) do
    double('Billing::Plans::Plan')
  end
  let(:plans) do
    double('Billing::Plans', {
      find: plan
    })
  end

  let(:stripe_event) do
    double('Billing::StripeEvent', {
      :provider_id => stripe_event_id,
      :bare? => false,
      :processed= => nil,
      :save! => nil
    })
  end
  let(:quota) do
    double('Quota', {
      save!: nil,
      add_minutes: nil,
      reset: nil
    })
  end
  let(:subscription) do
    double('Billing::Subscription', {
      plan: 'per_minute',
      start_period: Time.now.utc,
      end_period: Time.now.utc + 1.month,
      renewed!: nil,
      save!: nil
    })
  end
  let(:account) do
    double('Account', {
      billing_subscription: subscription,
      quota: quota
    })
  end

  before do
    Timecop.freeze(Time.now)
    relation.stub(:where).with(provider_id: stripe_event_id){ [stripe_event] }
    Billing::StripeEvent.stub(:pending){ relation }
    Account.stub(:find_by_billing_provider_customer_id){ account }
    Billing::Jobs::StripeEvent.stub(:plans){ plans }
  end

  after do
    Timecop.return
  end

  shared_examples 'processing completed' do
    it 'saves current time to stripe_event.processed' do
      stripe_event.should_receive(:processed=).with(Time.now)
      stripe_event.should_receive(:save!)
    end
  end

  context 'charge.succeeded' do
    let(:amount){ 12 }
    let(:event_data) do
      {
        object: {
          customer: stripe_customer_id,
          object: 'charge',
          amount: amount,
          metadata: {
            autorecharge: true
          }
        }
      }
    end
    before do
      stripe_event.stub(:name){ 'charge.succeeded' }
      stripe_event.stub(:data){ event_data }
      plan.stub(:per_minutes?){ true }
      plan.stub(:price_per_quantity){ 0.09 }
    end
    context 'when triggered by autorecharge' do
      after do
        subject.perform(stripe_event_id)
      end
      it 'tells quota to add_minutes and save!' do
        quota.should_receive(:add_minutes).with(plan, amount)
        quota.should_receive(:save!)
      end
      it_behaves_like 'processing completed'
    end

    context 'when not triggered by autorecharge' do
      before do
        event_data[:object][:metadata][:autorecharge] = false
      end
      after do
        subject.perform(stripe_event_id)
      end
      it 'does not tell quota to add minutes' do
        quota.should_not_receive(:add_minutes)
      end
      it_behaves_like 'processing completed'
    end
  end

  context 'charge.failed' do
  end

  context 'invoice.payment_succeeded' do
    let(:event_data) do
      {
        object: {
          customer: stripe_customer_id,
          object: 'invoice',
          lines: {
            data: [
              {
                type: 'subscription',
                period: {
                  :start => nil,
                  :end => nil
                }
              }
            ]
          }
        }
      }
    end
    before do
      stripe_event.stub(:name){ 'invoice.payment_succeeded' }
      stripe_event.stub(:data){ event_data }
      plan.stub(:per_minutes?){ false }
    end
    context 'when triggered by autorenewal' do
      let(:start_period){ Time.now }
      let(:end_period){ start_period + 1.month }
      before do
        subscription.stub(:is_renewal?){ true }
        event_data[:object][:lines][:data][0][:period] = {
          :start => start_period,
          :end => end_period
        }
      end
      after do
        subject.perform(stripe_event_id)
      end
      it 'tells subscription that it has been renewed!' do
        subscription.should_receive(:renewed!).with(start_period, end_period)
      end
      it 'tells quota to reset and save!' do
        quota.should_receive(:reset).with(plan)
        quota.should_receive(:save!)
      end
      it_behaves_like 'processing completed'
    end

    context 'when not triggered by autorenewal' do
      before do
        subscription.stub(:is_renewal?){ false }
      end
      after do
        subject.perform(stripe_event_id)
      end
      it 'does not tell subscription that it has been renewed!' do
        subscription.should_not_receive(:renewed!)
      end
      it 'does not tell quota to reset' do
        quota.should_not_receive(:reset)
      end
      it_behaves_like 'processing completed'
    end
  end

  context 'invoice.payment_failed' do
  end
end
