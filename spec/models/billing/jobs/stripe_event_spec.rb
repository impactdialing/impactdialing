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
      renewed: nil
    })
  end
  let(:subscription) do
    double('Billing::Subscription', {
      plan: 'per_minute',
      start_period: Time.now.utc,
      end_period: Time.now.utc + 1.month,
      renewed!: nil,
      autorecharge_paid!: nil,
      autorecharge_disable!: nil,
      cache_provider_status!: nil,
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
    quota.stub(:account){ account }
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
            autorecharge: "1"
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
      it 'tells subscription autorecharge_paid!' do
        subscription.should_receive(:autorecharge_paid!)
      end
      it 'tells quota to add_minutes and save!' do
        quota.should_receive(:add_minutes).with(plan, amount)
        quota.should_receive(:save!)
      end
      it_behaves_like 'processing completed'
    end

    context 'when not triggered by autorecharge' do
      before do
        event_data[:object][:metadata][:autorecharge] = "0"
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
    let(:amount){ 12 }
    let(:event_data) do
      {
        object: {
          customer: stripe_customer_id,
          object: 'charge',
          amount: amount,
          metadata: {
            autorecharge: "1"
          }
        }
      }
    end
    let(:mailer) do
      double('BillingMailer', {
        autorecharge_failed: nil
      })
    end
    before do
      stripe_event.stub(:data){ event_data }
      stripe_event.stub(:name){ 'charge.failed' }
      BillingMailer.stub(:new){ mailer }
    end
    after do
      subject.perform(stripe_event_id)
    end
    context 'when triggered by autorecharge' do
      it 'delivers BillingMailer.autorecharge_failed' do
        mailer.should_receive(:autorecharge_failed)
      end
      it 'tells subscription, autorecharge_disable!' do
        subscription.should_receive(:autorecharge_disable!)
      end
      it_behaves_like 'processing completed'
    end

    context 'when not triggered by autorecharge' do
      before do
        event_data[:object][:metadata][:autorecharge] = "0"
      end
      it 'delivers nothing' do
        BillingMailer.should_not_receive(:new)
      end
      it 'tells subscription nothing' do
        subscription.should_not_receive(:autorecharge_disable!)
      end
      it_behaves_like 'processing completed'
    end
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
        subscription.should_receive(:renewed!).with(
          start_period,
          end_period,
          'active'
        )
      end
      it 'tells quota to reset and save!' do
        quota.should_receive(:renewed).with(plan)
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
        quota.should_not_receive(:renewed)
      end
      it_behaves_like 'processing completed'
    end
  end

  context 'customer.subscription.updated' do
    let(:event_data) do
      {
        object: {
          customer: stripe_customer_id,
          object: 'subscription',
          type: 'subscription',
          period: {
            :start => nil,
            :end => nil
          },
          status: 'active'
        }
      }
    end
    let(:mailer) do
      double('BillingMailer', {
        autorenewal_failed: nil
      })
    end
    before do
      stripe_event.stub(:data){ event_data }
      stripe_event.stub(:name){ 'invoice.payment_failed' }
      BillingMailer.stub(:new){ mailer }
    end
    after do
      subject.perform(stripe_event_id)
    end
    context 'when triggered by autorenewal' do
      before do
        subscription.stub(:is_renewal?){ true }
      end
      it 'delivers BillingMailer.autorenewal_failed' do
        mailer.should_receive(:autorenewal_failed)
      end
      it 'tells subscription cache_provider_status!(status)' do
        subscription.should_receive(:cache_provider_status!).with(event_data[:object][:lines][:data][0][:status])
      end
      it_behaves_like 'processing completed'
    end

    context 'when not triggered by autorenewal' do
      before do
        subscription.stub(:is_renewal?){ false }
      end
      it 'delivers nothing' do
        mailer.should_not_receive(:autorenewal_failed)
      end
      it 'tells subscription nothing' do
        subscription.should_not_receive(:cache_provider_status!)
      end
      it_behaves_like 'processing completed'
    end
  end
end
