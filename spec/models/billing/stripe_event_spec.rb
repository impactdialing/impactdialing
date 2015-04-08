require 'rails_helper'
require 'date'

describe 'Billing::StripeEvent' do
  
  let(:stripe_event) do
    double('Fake::Stripe::Event', {
      "id" => "evt_15iWXp2eZvKYlo2CM8pTwzYK",
      "created" => 1426882597,
      "livemode" => false,
      "type" => "customer.subscription.updated",
      "data" => {
        "object" => {
          "id" => "sub_4RJ3mQkY5D7jM1",
          "plan" => {
            "interval" => "month",
            "name" => "Starter",
            "created" => 1405886260,
            "amount" => 0,
            "currency" => "usd",
            "id" => "w7lwgq",
            "object" => "plan",
            "livemode" => false,
            "interval_count" => 1,
            "trial_period_days" => nil,
            "metadata" => {
            },
            "statement_descriptor" => nil
          },
          "object" => "subscription",
          "start" => 1405886261,
          "status" => "active",
          "customer" => "cus_4RJ3GM7YPNilvV",
          "cancel_at_period_end" => false,
          "current_period_start" => 1426881461,
          "current_period_end" => 1429559861,
          "ended_at" => nil,
          "trial_start" => nil,
          "trial_end" => nil,
          "canceled_at" => nil,
          "quantity" => 1,
          "application_fee_percent" => nil,
          "discount" => nil,
          "tax_percent" => nil,
          "metadata" => {
          }
        },
        "previous_attributes" => {
          "current_period_start" => 1424462261,
          "current_period_end" => 1426881461
        }
      },
      "object" => "event",
      "pending_webhooks" => 1,
      "request" => 123,
      "api_version" => "2015-02-18"
    })
  end

  describe 'cache_event!(stripe_event_instance)' do
    let(:billing_stripe_event) do
      Billing::StripeEvent.create!(provider_id: stripe_event.id)
    end
    before do
      billing_stripe_event.cache_event!(stripe_event)
    end

    it 'caches :data as serialized HashWithIndifferentAccess' do
      expect(billing_stripe_event.data[:object][:plan][:name]).to eq stripe_event.data['object']['plan']['name']
    end

    it 'caches :type as :name' do
      expect(billing_stripe_event.name).to eq stripe_event.type
    end

    it 'caches :livemode' do
      expect(billing_stripe_event.livemode).to eq stripe_event.livemode
    end

    it 'caches :provider_created_at' do
      expect(billing_stripe_event.provider_created_at).to eq Time.at(stripe_event.created).to_date
    end

    it 'caches :pending_webhooks' do
      expect(billing_stripe_event.pending_webhooks).to eq stripe_event.pending_webhooks
    end

    it 'caches :request' do
      expect(billing_stripe_event.request).to eq stripe_event.request
    end
  end
end

# ## Schema Information
#
# Table name: `billing_stripe_events`
#
# ### Columns
#
# Name                       | Type               | Attributes
# -------------------------- | ------------------ | ---------------------------
# **`id`**                   | `integer`          | `not null, primary key`
# **`provider_id`**          | `string(255)`      | `not null`
# **`provider_created_at`**  | `date`             |
# **`name`**                 | `string(255)`      |
# **`request`**              | `string(255)`      |
# **`pending_webhooks`**     | `integer`          |
# **`data`**                 | `text`             |
# **`processed`**            | `datetime`         |
# **`livemode`**             | `boolean`          |
# **`created_at`**           | `datetime`         | `not null`
# **`updated_at`**           | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_billing_stripe_events_on_provider_id`:
#     * **`provider_id`**
#
