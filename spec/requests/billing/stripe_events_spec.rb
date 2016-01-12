require 'rails_helper'

describe 'Store a new Stripe Event' do
  let(:stripe_params) do
    {id: '123', livemode: '0'}
  end
  let(:fake_rails_env) do
    double('Rails.env', {
      development?:    true,
      heroku_staging?: false,
      heroku?:         false
    })
  end
  before do
    allow(Rails).to receive(:env){ fake_rails_env }
  end
  after do
    allow(Rails).to receive(:env).and_call_original
  end

  it 'creates a new Billing::StripeEvent record w/ :provider_id' do
    expect{
      post billing_events_stripe_path, stripe_params
    }.to change{ Billing::StripeEvent.count }.by(1)
    expect(Billing::StripeEvent.last.provider_id).to eq stripe_params[:id]
  end

  it 'queues Billing::Jobs::StripeEvent for new event record' do
    post billing_events_stripe_path, stripe_params
    expect(resque_jobs(:billing)).to include({
      'class' => 'Billing::Jobs::StripeEvent',
      'args' => [stripe_params[:id]]
    })
  end
end
