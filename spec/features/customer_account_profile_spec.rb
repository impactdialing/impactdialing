require 'spec_helper'
include JSHelpers

def select_plan(type='Basic')
  select type, from: 'Select plan:'
end

def enter_n_callers(n)
  fill_in 'Number of callers:', with: n
end

def submit_valid_upgrade
  select_plan 'Basic'
  enter_n_callers 2
  click_on 'Upgrade'
end

def fill_in_expiration
  # verify jquery datepicker is working
  page.execute_script('$("#expiration_date").datepicker("show")')
  page.execute_script('$("select[data-handler=\"selectMonth\"]").val("0")')
  page.execute_script('$("select[data-handler=\"selectYear\"]").val("2020")')
  page.execute_script('$("#expiration_date").datepicker("hide")')
  expect(page.find_field('Expiration date').value).to eq "01/2020"
end

def add_valid_payment_info
  go_to_update_billing
  fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
  fill_in 'CVC', with: 123
  fill_in_expiration
  click_on 'Update payment information'
  expect(page).to have_content I18n.t('subscriptions.update_billing.success')
end

def go_to_billing
  click_on 'Account'
  click_on 'Billing'
end

def go_to_upgrade
  go_to_billing
  click_on 'Upgrade'
end

def go_to_update_billing
  go_to_billing
  click_on 'Update card'
end

def expect_monthly_cost_eq(expected_cost)
  within('#cost-subscription') do
    expect(page).to have_content "$#{expected_cost} per month"
  end
end

describe 'Account profile', type: :feature, admin: true do
  let(:user){ create(:user) }
  before do
    web_login_as(user)
  end

  describe 'when a user creates a new account' do
    before do
      click_on 'Log out'
    end
    it 'with a valid email and password' do
      user = build :user
      visit '/client/login'
      fill_in 'Email address', :with => user.email
      fill_in 'Pick a password', :with => user.new_password
      click_button 'Sign up'
      expect(page).to have_content 'Log out'
    end
  end

  describe 'when a user edits their information' do
    it 'with valid information' do
      click_link 'Account'
      fill_in 'Email address', :with => 'new@email.com'
      click_button 'Update info'
      expect(page).to have_content 'Your information has been updated.'
    end

    xit 'and changes their password' do
      user = build :user
      click_link 'Account'
      fill_in 'Current password', :with => user.new_password
      fill_in 'New password', :with => '1newpassword!'
      click_button 'Update password'
      expect(page).to have_content 'Your password has been changed.'
    end

    xit 'and tries to change their password with an invalid password' do
      click_link 'Account'
      fill_in 'Current password', :with => 'wrong'
      fill_in 'New password', :with => '1newpassword!'
      click_button 'Update password'
      expect(page).to have_content 'Your current password was not correct.'
    end
  end

  describe 'Billing', js: true do
    it 'Upgrade button is disabled until payment info exists' do
      go_to_billing

      expect(page).not_to have_text 'Upgrade'
    end

    context 'Adding valid payment info' do
      before do
        go_to_update_billing
      end

      it 'displays subscriptions.update_billing.success after form submission' do
        fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
        fill_in 'CVC', with: 123
        fill_in_expiration
        click_on 'Update payment information'
        expect(page).to have_content I18n.t('subscriptions.update_billing.success')
      end
    end

    context 'Upgrading with valid payment info' do
      it 'displays subscriptions.upgrade.success after form submission' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Basic'
        enter_n_callers 2
        click_on 'Upgrade'

        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    context 'bug#70705768 - Updating card info when stripe customer email does not match any account user emails' do
      before do
        user.email = 'nada.nowhere@test.com'
        user.save!
        create(:user, {account: user.account})
      end

      it 'allows for new invoice recipient to be selected' do
        go_to_update_billing
        fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
        fill_in 'CVC', with: 123
        fill_in_expiration
        select user.email, from: 'Who should we send invoices to?'
        click_on 'Update payment information'
        expect(page).to have_content I18n.t('subscriptions.update_billing.success')
      end
    end

    describe 'Upgrade from Trial to Basic plan' do
      let(:cost){ 49 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        enter_n_callers 1
        select_plan 'Basic'
        expect_monthly_cost_eq cost
        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"
        click_on 'Upgrade'

        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade from Trial to Pro plan' do
      let(:cost){ 99 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        enter_n_callers 1
        expect_monthly_cost_eq cost

        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"

        click_on  'Upgrade'
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade from Trial to Per minute' do
      let(:cost){ 0.09 }
      let(:amount){ 9 }
      let(:minutes){ amount / cost }

      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Per minute'
        fill_in 'Add to balance:', with: amount
        click_on 'Upgrade'
      end

      it 'adds user designated amount of funds to the account' do
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end

      it 'updates the account quota so only the purchased minutes are available, trial minutes are not' do
        expect(page).to have_content "Minutes left: #{minutes.to_i}"
      end

      describe 'with blank Add to balance field' do
        let(:cost){ 0.09 }
        let(:amount){ 9 }
        let(:minutes){ amount / cost }

        before do
          add_valid_payment_info
          go_to_upgrade
          select_plan 'Per minute'
          fill_in 'Add to balance:', with: 0
          click_on 'Upgrade'
        end

        it 'displays billing.plans.transition_errors.amount_paid' do
          error = I18n.t('billing.plans.transition_errors.amount_paid')
          expect(page).to have_content error
        end
      end
    end

    describe 'Downgrading from Pro to Basic' do
      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        enter_n_callers 1
        click_on 'Upgrade'
        expect(page).to have_content "Minutes left: 2500"
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end
      it 'performs live update of monthly cost as plan and caller inputs change' do
        go_to_upgrade
        select_plan 'Basic'
        enter_n_callers 1
        expect_monthly_cost_eq 49
        click_on 'Upgrade'
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Change from PerMinute (100 minutes available) to Pro w/ 1 caller', selenium: true do
      let(:amount){ 9 }
      let(:cost){ 0.09 }
      let(:available_per_minute){ (amount / cost).to_i }
      let(:minutes_from_recurring){ 2500 }
      let(:account){ user.account }
      let(:quota){ account.quota }
      let(:subscription){ account.billing_subscription }
      let(:customer) do
        Stripe::Customer.create({
          card: {
            number: '4242424242424242',
            exp_month: Date.today.month,
            exp_year: Date.today.year + 1
          },
          email: user.email
        })
      end

      before do
        account.billing_provider_customer_id = customer.id
        account.save!
        manager = Billing::SubscriptionManager.new(account.billing_provider_customer_id, subscription, quota)
        manager.update!('per_minute', {amount_paid: amount}) do |provider_object, opts|
          subscription.plan_changed!('per_minute', provider_object, opts)
          quota.plan_changed!('per_minute', provider_object, opts)
        end
        expect(quota.minutes_available).to eq available_per_minute
        expect(subscription.plan).to eq 'per_minute'
      end

      it 'will add remaining minutes from PerMinute purchase to total minutes of the selected recurring plan' do
        go_to_upgrade
        select_plan 'Pro'
        enter_n_callers 1
        click_on 'Upgrade'
        expect(page).to have_content "Minutes left: #{available_per_minute + minutes_from_recurring}"
      end
      context '10 days into Pro billing cycle' do
        # it_behaves_like 'customer keeps remaining minutes'
      end

    end

    describe 'Adding time to PerMinute' do
      let(:amount){ 9 }
      let(:minutes_purchased){ (amount / 0.09).to_i }
      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Per minute'
        fill_in 'Add to balance:', with: amount
        click_on 'Upgrade'
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
        expect(page).to have_content "Minutes left: #{minutes_purchased}"
      end

      it 'Manually add funds' do
        go_to_billing
        fill_in 'Amount to add', with: 9
        click_on 'Add funds'
        expect(page).to have_content I18n.t('subscriptions.upgrade.success')
        expect(page).to have_content "Minutes left: #{minutes_purchased * 2}"
      end

      it 'Can be configured to automatically add funds' do
        go_to_billing
        choose 'On'
        fill_in 'If Minutes left falls below', with: 100
        fill_in 'Then Add funds, spending', with: 45
        click_on 'Save'

        expect(page).to have_content I18n.t('subscriptions.autorecharge.update')
        expect(page).to have_content "$45 (500 minutes) will be automatically added when there are less than 100 Minutes left."
      end

      it 'Can have automatic fund additions disabled' do
        go_to_billing
        choose 'On'
        fill_in 'If Minutes left falls below', with: 100
        fill_in 'Then Add funds, spending', with: 45
        click_on 'Save'
        expect(page).to have_content I18n.t('subscriptions.autorecharge.update')
        expect(page).to have_content "$45 (500 minutes) will be automatically added when there are less than 100 Minutes left."

        choose 'Off'
        click_on 'Save'
        expect(page).to have_content I18n.t('subscriptions.autorecharge.update')
        expect(page).not_to have_content "$45 (500 minutes) will be automatically added when there are less than 100 Minutes left."
      end
    end

    describe 'cancelling a recurring subscription', webkit: true do
      let(:account){ user.account }
      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        enter_n_callers 1
        click_on 'Upgrade'
        expect(page).to have_content "Minutes left: 2500"
        go_to_billing
        click_on 'Cancel subscription'
        # should work to handle alerts/confirms on selenium, but not currently
        # a = page.driver.browser.switch_to.alert
        # a.accept  # can also be a.dismiss
      end
      it 'displays flash notice when successful' do
        expect(page).to have_content I18n.t('subscriptions.cancelled')
        expect(page).to have_content "You have cancelled your subscription."
      end
    end
  end
end
