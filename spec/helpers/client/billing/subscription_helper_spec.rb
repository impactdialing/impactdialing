require 'spec_helper'

describe Client::Billing::SubscriptionHelper, :type => :helper do
  let(:account){ mock_model('Account') }
  let(:user){ mock_model('User') }
  let(:ability) do
    double('Ability', {
      can?: false
    })
  end
  let(:subscription) do
    double('Billing::Subscription', {
      id: 1,
      plan: 'basic'
    })
  end

  before do
    # account.stub(:billing_subscription){ subscription }
    allow(account).to receive(:users){ [user] }
    allow(controller).to receive(:current_user){ account }
    allow(Ability).to receive(:new){ ability }
  end
  describe '#subscription_type_options_for_select(subscription, minutes_available)' do
    it 'maps Billing::Plans.permitted_ids_for collection of display,value pairs to select options' do
      allow(Billing::Plans).to receive(:permitted_ids_for){ ["basic", "pro", "business"] }
      expected = [
        ["Basic", "basic"], ["Pro", "pro"], ["Business", "business"]
      ]
      expect(helper.subscription_type_options_for_select(subscription, true)).to eq expected
    end
  end

  describe '#subscription_update_billing_button(subscription)' do
    it 'returns array of link_to args' do
      actual = helper.subscription_update_billing_button(subscription)

      expect(actual[0]).to eq 'Update card'
      expect(actual[1]).to eq client_billing_credit_card_path
      expect(actual[2]).to eq({class: 'action primary confirm'})
    end
  end

  describe '#subscription_cancel_button(subscription)' do
    context 'can? :cancel_subscription is false' do
      before do
        allow(ability).to receive(:can?).with(:cancel_subscription, subscription){ false }
      end

      it 'returns empty array' do
        actual = helper.subscription_cancel_button(subscription)

        expect(actual).to eq []
      end
    end

    context 'can? :cancel_subscription is true' do
      before do
        allow(ability).to receive(:can?).with(:cancel_subscription, subscription){ true }
      end

      it 'returns an array of link_to args to cancel subscription' do
        actual = helper.subscription_cancel_button(subscription)

        expect(actual[0]).to eq 'Cancel subscription'
        expect(actual[1]).to eq({
          action: 'cancel'
        })
        expect(actual[2]).to eq({
          method: 'put',
          class: 'action secondary',
          confirm: 'Are you sure you want to cancel your subscription?'
        })
      end
    end
  end

  describe '#subscription_upgrade_button(subscription)' do
    context 'can? :make_payment is false' do
      before do
        allow(ability).to receive(:can?).with(:make_payment, subscription){ false }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ true }
      end
      it 'returns an empty array' do
        actual = helper.subscription_upgrade_button(subscription)

        expect(actual).to eq []
      end
    end

    context 'can? :change_plans is false' do
      before do
        allow(ability).to receive(:can?).with(:make_payment, subscription){ true }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ false }
      end
      it 'returns an empty array' do
        actual = helper.subscription_upgrade_button(subscription)

        expect(actual).to eq []
      end
    end

    context 'can? :make_payment is true AND can? :change_plans is true' do
      before do
        expect(ability).to receive(:can?).with(:make_payment, subscription){ true }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ true }
      end
      it 'returns an array of link_to args to subscription' do
        actual = helper.subscription_upgrade_button(subscription)

        expect(actual[0]).to eq 'Upgrade'
        expect(actual[1]).to eq edit_client_billing_subscription_path
        expect(actual[2]).to eq({class: 'action primary confirm'})
      end
    end
  end

  describe '#subscription_buttons(subscription)' do
    context 'can? :make_payment, can? :cancel_subscription AND can? :change_plans are true' do
      before do
        allow(ability).to receive(:can?).with(:make_payment, subscription){ true }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ true }
        allow(ability).to receive(:can?).with(:cancel_subscription, subscription){ true }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Upgrade' do
        expect(@actual[0][0]).to eq 'Upgrade'
      end

      it 'Update card' do
        expect(@actual[1][0]).to eq 'Update card'
      end

      it 'Cancel subscription' do
        expect(@actual[2][0]).to eq 'Cancel subscription'
      end
    end

    context 'can? :make_payment, can? :change_plans are true and can? :cancel_subscription is false' do
      before do
        allow(ability).to receive(:can?).with(:make_payment, subscription){ true }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ true }
        allow(ability).to receive(:can?).with(:cancel_subscription, subscription){ false }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Upgrade' do
        expect(@actual[0][0]).to eq 'Upgrade'
      end

      it 'Update card' do
        expect(@actual[1][0]).to eq 'Update card'
      end
    end

    context 'can? :make_payment, can? :change_plans are false and can? :cancel_subscription is true' do
      before do
        allow(ability).to receive(:can?).with(:make_payment, subscription){ false }
        allow(ability).to receive(:can?).with(:change_plans, subscription){ false }
        allow(ability).to receive(:can?).with(:cancel_subscription, subscription){ true }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Update card' do
        expect(@actual[0][0]).to eq 'Update card'
      end

      it 'Cancel subscription' do
        expect(@actual[1][0]).to eq 'Cancel subscription'
      end
    end
  end
end