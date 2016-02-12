require 'rails_helper'

describe 'Subscription billing page', type: :feature, admin: true do

  let(:user){ create(:user) }
  let(:account){ user.account }


  before do
    web_login_as(user)
  end

  def go_to_billing
    click_on 'Account'
    click_on 'Billing'
  end
  context 'subscriptions without a billing period' do
    shared_examples 'Ad-hoc plans' do
      it 'does not display start/end dates' do
        visit client_billing_subscription_path
        expect(page).to_not have_content 'Billing period:'
      end
    end

    context 'Trial' do
      before do
        account.billing_subscription.update_attributes!({
          plan: 'trial'
        })
      end
      it_behaves_like 'Ad-hoc plans'
    end

    context 'PerMinute' do
      before do
        account.billing_subscription.update_attributes!({
          plan: 'per_minute'
        })
      end
      it_behaves_like 'Ad-hoc plans'
    end

    context 'Enterprise' do
      before do
        account.billing_subscription.update_attributes!({
          plan: 'enterprise'
        })
      end
      it_behaves_like 'Ad-hoc plans'
    end
  end

  context 'subscriptions with a billing cycle' do
    context 'Business Plans' do
      context 'Basic' do
        before do
          account.billing_subscription.update_attributes!({
            provider_start_period: 20.days.ago.to_i,
            provider_end_period: 10.days.from_now.to_i,
            plan: 'basic'
          })
        end
        it 'does display start/end dates' do
          visit client_billing_subscription_path
          expect(page).to have_content "Billing period:"
        end
      end
    end
  end
end
