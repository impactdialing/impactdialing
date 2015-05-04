require 'rails_helper'

describe 'Account profile', type: :feature, admin: true do

  let(:user){ create(:user) }
  let(:account){ user.account }


  before do
    web_login_as(user)
  end

  def go_to_billing
    click_on 'Account'
    click_on 'Billing'
  end

  # shared_examples 'no billing period info to display' do
  #   it 'does not display billing period info' do
  #     visit client_billing_subscription_path
  #     expect(page).to have_content 'Start period:'
  #   end
  # end
  #
  # context 'when subscribed plan is Trial' do
  #   it 'does not display billing period info'
  # end
  #
  # context 'when subscribed plan is PerMinute' do
  #   it_behaves_like 'no billing period info to display'
  # end
  #
  # context 'when subscribed plan is Enterprise' do
  #   it_behaves_like 'no billing period info to display'
  # end

  shared_examples 'all business plans' do
    it 'displays billing period info' do
      visit client_billing_subscription_path
      expect(page).to have_content "Start period: #{Time.at(subscription.provider_start_period).strftime('%m/%d/%y')}"
    end
  end

  context 'when subscribed plan is' do
    context 'Basic' do
      before do
        account.billing_subscription.update_attributes!({
          provider_start_period: 20.days.ago.to_i,
          provider_end_period: 10.days.from_now.to_i,
          plan: 'basic'
        })
      end
      let(:subscription) do
        account.billing_subscription
      end
      it_behaves_like 'all business plans'
    end

    # context 'Pro' do
    #   let(:subscription){ create :subscription, plan: 'pro' }
    #   it_behaves_like 'all business plans'
    # end
    #
    # context 'Business' do
    #   let(:subscription){ create :subscription, plan: 'business' }
    #   it_behaves_like 'all business plans'
    # end
  end
end
