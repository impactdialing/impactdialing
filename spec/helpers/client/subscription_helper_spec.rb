require 'spec_helper'

describe Client::SubscriptionHelper do
  describe '#subscription_type_options_for_select' do
    it 'returns a collection of display,value pairs for select options' do
      expected = [
        ["Basic", "Basic"], ["Pro", "Pro"], ["Business", "Business"],
        ["Per minute", "PerMinute"]
      ]
      helper.subscription_type_options_for_select.should eq expected
    end
  end

  describe '#subscription_upgrade_button(subscription, enabled=true)' do
    let(:subscription) do
      create(:trial, {
        number_of_callers: 1
      })
    end

    context 'when subscription has a stripe customer id' do
      before do
        subscription.stripe_customer_id = 1
      end
      it 'returns a link to subscription' do
        actual = helper.subscription_upgrade_button(subscription)

        actual.should have_text 'Upgrade'
        actual.should have_css 'a'
        actual.should have_css "[href$='#{client_subscription_path(subscription)}']"
        actual.should have_css "[class='action primary confirm']"
      end
    end

    context 'when a subscription does not have a stripe customer id' do
      it 'returns a span button look alike' do
        actual = helper.subscription_upgrade_button(subscription)

        actual.should have_text 'Upgrade'
        actual.should have_css 'span'
        actual.should have_css "[class='disabled']"
      end
    end
  end
end