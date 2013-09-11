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

def add_valid_payment_info
  go_to_update_billing
  fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
  fill_in 'CVC', with: 123
  select '1 - January', from: 'Month'
  select '2018', from: 'Year'
  click_on 'Update payment information'
  page.should have_content 'Billing info updated successfully!'
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
  click_on 'Update billing info'
end

def expect_monthly_cost_eq(expected_cost)
  # sleep(0.1)
  # blur('#subscription_type')
  # blur('#number_of_callers')
  # sleep(0.3)

  within('#cost-subscription') do
    page.should have_content "$#{expected_cost} per month"
  end
end

describe 'Account profile' do
  let(:user){ create(:user) }
  before do
    web_login_as(user)
  end

  describe 'Billing', js: true do
    it 'Upgrade button is disabled until payment info exists' do
      go_to_billing

      within('span.disabled') do
        page.should have_text 'Upgrade'
      end
    end

    context 'Adding valid payment info' do
      before do
        go_to_update_billing
      end

      it 'displays subscriptions.update_billing.success after form submission' do
        fill_in 'Card number', with: StripeFakes.valid_cards[:visa].first
        fill_in 'CVC', with: 123
        select '1 - January', from: 'Month'
        select '2018', from: 'Year'
        click_on 'Update payment information'
        page.should have_content 'Billing info updated successfully!'
      end
    end

    context 'Upgrading with valid payment info' do
      it 'displays subscriptions.upgrade.success after form submission' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Basic'
        enter_n_callers 2
        click_on 'Upgrade'

        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade to Basic plan' do
      let(:cost){ 49 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Basic'
        expect_monthly_cost_eq cost
        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"
        click_on 'Upgrade'

        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Upgrade to Pro plan' do
      let(:cost){ 99 }
      let(:callers){ 2 }

      it 'performs live update of monthly cost as plan and caller inputs change' do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        expect_monthly_cost_eq cost

        enter_n_callers callers
        expect_monthly_cost_eq "#{cost * callers}"

        click_on  'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end

    describe 'Downgrading from Pro to Basic' do
      before do
        add_valid_payment_info
        go_to_upgrade
        select_plan 'Pro'
        click_on 'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
      it 'performs live update of monthly cost as plan and caller inputs change' do
        go_to_upgrade
        select_plan 'Basic'
        expect_monthly_cost_eq 49
        click_on 'Upgrade'
        page.should have_content I18n.t('subscriptions.upgrade.success')
      end
    end
  end
end
