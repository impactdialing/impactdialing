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

  describe '#subscription_update_billing_button(subscription)' do
    let(:subscription) do
      create(:trial, {
        number_of_callers: 1
      })
    end

    it 'returns an array of link_to args to update billing info for subscription' do
      actual = helper.subscription_update_billing_button(subscription)

      actual[0].should eq 'Update billing info'
      actual[1].should eq update_billing_client_subscription_path(subscription)
      actual[2].should eq({class: 'action primary confirm'})
    end
  end

  describe 'Per minute subscription buttons' do
    let(:subscription) do
      create(:per_minute, {
        number_of_callers: 1
      })
    end

    describe '#subscription_configure_auto_recharge_button(subscription)' do
      it 'returns an array of link_to args to update auto recharge settings' do
        actual = helper.subscription_configure_auto_recharge_button(subscription)
        actual.should eq [
          'Configure auto-recharge',
          configure_auto_recharge_client_subscription_path(subscription),
          {class: 'action primary'}
        ]
      end
    end

    describe '#subscription_add_to_balance_button' do
      it 'returns an array of link_to args to add to balance' do
        actual = helper.subscription_add_to_balance_button(subscription)
        actual.should eq [
          'Add to your balance',
          add_funds_client_subscription_path(subscription),
          {class: 'action primary'}
        ]
      end
    end
  end

  describe '#subscription_buttons(subscription)' do
    context 'subscription is Per minute' do
      let(:subscription) do
        create(:per_minute, {
          number_of_callers: 1
        })
      end

      before do
        @actual = helper.subscription_buttons(subscription)
      end

      it 'returns an array of 3 items, one for each button to render' do
        @actual.size.should eq 3
      end

      it 'first button is for add to balance' do
        @actual[0].should eq helper.subscription_add_to_balance_button(subscription)
      end

      it 'second button is for configure auto-recharge' do
        @actual[1].should eq helper.subscription_configure_auto_recharge_button(subscription)
      end

      it 'third button is for update billing info' do
        @actual[2].should eq helper.subscription_update_billing_button(subscription)
      end
    end

    context 'subscription is Per agent' do
      context 'and Trial' do
        let(:subscription) do
          create(:trial, {
            number_of_callers: 1
          })
        end

        context 'with no billing info' do
          before do
            @actual = helper.subscription_buttons(subscription)
          end

          it 'returns args for a single link' do
            @actual.size.should eq 1
          end

          it 'returns args to update billing info' do
            @actual.should eq [helper.subscription_update_billing_button(subscription)]
          end
        end

        context 'with billing info' do
          before do
            subscription.stripe_customer_id = 1
            @actual = helper.subscription_buttons(subscription)
          end

          it 'returns args for 2 links' do
            @actual.size.should eq 2
          end

          it 'returns args to update billing info' do
            @actual[0].should eq helper.subscription_update_billing_button(subscription)
          end

          it 'returns args to upgrade plan' do
            @actual[1].should eq helper.subscription_upgrade_button(subscription)
          end
        end
      end

      context 'and not Trial' do
        let(:subscription) do
          create(:basic, {
            number_of_callers: 1,
            stripe_customer_id: 3
          })
        end

        before do
          @actual = helper.subscription_buttons(subscription)
        end

        it 'returns args for 3 links' do
          @actual.size.should eq 3
        end

        it 'returns args to update billing info' do
          @actual[0].should eq helper.subscription_update_billing_button(subscription)
        end

        it 'returns args to upgrade plan' do
          @actual[1].should eq helper.subscription_upgrade_button(subscription)
        end

        it 'returns args to cancel subscription' do
          @actual[2].should eq helper.subscription_cancel_button(subscription)
        end
      end
    end
  end

  describe '#subscription_cancel_button(subscription)' do
    context 'when subscription is a trial' do
      let(:subscription) do
        create(:trial, {
          number_of_callers: 1
        })
      end

      it 'returns an empty array' do
        actual = helper.subscription_cancel_button(subscription)

        actual.should eq []
      end
    end

    context 'when subscription is not a trial' do
      let(:subscription) do
        create(:basic, {
          number_of_callers: 1
        })
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
    let(:subscription) do
      create(:trial, {
        number_of_callers: 1
      })
    end

    context 'when subscription has a stripe customer id' do
      before do
        subscription.stripe_customer_id = 1
      end
      it 'returns an array of link_to args to subscription' do
        actual = helper.subscription_upgrade_button(subscription)

        actual[0].should eq 'Upgrade'
        actual[1].should eq client_subscription_path(subscription)
        actual[2].should eq({class: 'action primary confirm'})
      end
    end

    context 'when a subscription does not have a stripe customer id' do
      it 'returns an empty array' do
        actual = helper.subscription_upgrade_button(subscription)

        actual.should eq []
      end
    end
  end
end