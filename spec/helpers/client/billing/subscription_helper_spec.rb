require 'spec_helper'

describe Client::Billing::SubscriptionHelper do
  let(:account){ mock_model('Account') }
  let(:user){ mock_model('User') }
  let(:ability) do
    double('Ability', {
      can?: false
    })
  end
  let(:subscription) do
    double('Billing::Subscription', {
      id: 1
    })
  end

  before do
    # account.stub(:billing_subscription){ subscription }
    account.stub(:users){ [user] }
    controller.stub(:current_user){ account }
    Ability.stub(:new){ ability }
  end
  describe '#subscription_type_options_for_select' do
    it 'maps the Billing::Plans.ids collection of display,value pairs for select options' do
      Billing::Plans.stub(:ids){ ["basic", "pro", "business"] }
      expected = [
        ["Basic", "basic"], ["Pro", "pro"], ["Business", "business"]
      ]
      helper.subscription_type_options_for_select.should eq expected
    end
  end

  describe '#subscription_update_billing_button(subscription)' do
    it 'returns array of link_to args' do
      actual = helper.subscription_update_billing_button(subscription)

      actual[0].should eq 'Update card'
      actual[1].should eq client_billing_credit_card_path
      actual[2].should eq({class: 'action primary confirm'})
    end
  end

  describe '#subscription_cancel_button(subscription)' do
    context 'can? :cancel_subscription is false' do
      before do
        ability.stub(:can?).with(:cancel_subscription, subscription){ false }
      end

      it 'returns empty array' do
        actual = helper.subscription_cancel_button(subscription)

        actual.should eq []
      end
    end

    context 'can? :cancel_subscription is true' do
      before do
        ability.stub(:can?).with(:cancel_subscription, subscription){ true }
      end

      it 'returns an array of link_to args to cancel subscription' do
        actual = helper.subscription_cancel_button(subscription)

        actual[0].should eq 'Cancel subscription'
        actual[1].should eq({
          action: 'cancel',
          id: subscription.id
        })
        actual[2].should eq({
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
        ability.stub(:can?).with(:make_payment, subscription){ false }
        ability.stub(:can?).with(:change_plans, subscription){ true }
      end
      it 'returns an empty array' do
        actual = helper.subscription_upgrade_button(subscription)

        actual.should eq []
      end
    end

    context 'can? :change_plans is false' do
      before do
        ability.stub(:can?).with(:make_payment, subscription){ true }
        ability.stub(:can?).with(:change_plans, subscription){ false }
      end
      it 'returns an empty array' do
        actual = helper.subscription_upgrade_button(subscription)

        actual.should eq []
      end
    end

    context 'can? :make_payment is true AND can? :change_plans is true' do
      before do
        ability.should_receive(:can?).with(:make_payment, subscription){ true }
        ability.stub(:can?).with(:change_plans, subscription){ true }
      end
      it 'returns an array of link_to args to subscription' do
        actual = helper.subscription_upgrade_button(subscription)

        actual[0].should eq 'Upgrade'
        actual[1].should eq edit_client_billing_subscription_path
        actual[2].should eq({class: 'action primary confirm'})
      end
    end
  end

  describe '#subscription_buttons(subscription)' do
    context 'can? :make_payment, can? :cancel_subscription AND can? :change_plans are true' do
      before do
        ability.stub(:can?).with(:make_payment, subscription){ true }
        ability.stub(:can?).with(:change_plans, subscription){ true }
        ability.stub(:can?).with(:cancel_subscription, subscription){ true }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Upgrade' do
        @actual[0][0].should eq 'Upgrade'
      end

      it 'Update card' do
        @actual[1][0].should eq 'Update card'
      end

      it 'Cancel subscription' do
        @actual[2][0].should eq 'Cancel subscription'
      end
    end

    context 'can? :make_payment, can? :change_plans are true and can? :cancel_subscription is false' do
      before do
        ability.stub(:can?).with(:make_payment, subscription){ true }
        ability.stub(:can?).with(:change_plans, subscription){ true }
        ability.stub(:can?).with(:cancel_subscription, subscription){ false }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Upgrade' do
        @actual[0][0].should eq 'Upgrade'
      end

      it 'Update card' do
        @actual[1][0].should eq 'Update card'
      end
    end

    context 'can? :make_payment, can? :change_plans are false and can? :cancel_subscription is true' do
      before do
        ability.stub(:can?).with(:make_payment, subscription){ false }
        ability.stub(:can?).with(:change_plans, subscription){ false }
        ability.stub(:can?).with(:cancel_subscription, subscription){ true }
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'Update card' do
        @actual[0][0].should eq 'Update card'
      end

      it 'Cancel subscription' do
        @actual[1][0].should eq 'Cancel subscription'
      end
    end
  end
end