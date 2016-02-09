require 'rails_helper'

feature 'Internal Admin pages', admin: true do
  def for_last_user(&block)
    within(main_table_css) do
      within(last_row) do
        yield
      end
    end
  end

  def visit_users_page
    visit '/admin/users'
  end

  def visit_subscription_page
    visit_users_page
    account = User.last.account
    for_last_user do
      click_on "#{account.billing_subscription.plan.humanize.capitalize} ($#{account.billing_subscription.price_per_quantity} /min)"
    end

    expect(page).to have_content "Account ##{account.id}"
    expect(page).to have_content "Users: #{account.users.count}"
  end
  def set_account_to_manual
    visit_users_page

    for_last_user do
      click_on 'Make Enterprise'
    end

    expect(page).to have_content 'Subscription updated.'
  end

  def set_account_to_trial
    visit_users_page

    for_last_user do
      click_on 'Make Trial'
    end

    expect(page).to have_content 'Subscription updated.'
  end

  def expect_current_subscription_to_eq type, minutes
    visit_subscription_page

    expect(page).to have_content "Current plan: #{type}"
    if type == 'Enterprise'
      expect(page).to have_content "Minutes used: #{minutes}"
    else
      expect(page).to have_content "Minutes left: #{minutes}"
    end
  end

  let(:admin) do
    create(:user)
  end
  let(:super_admin) do
    create(:user, {
      new_password: 't3st3r'
    })
  end
  let(:campaign1) do
    create(:campaign, {
      account: admin.account
    })
  end
  let(:campaign2) do
    create(:campaign, {
      account: admin.account
    })
  end
  let(:caller1a) do
    create(:caller, {
      campaign: campaign1
    })
  end
  let(:caller1b) do
    create(:caller, {
      account: admin.account,
      campaign: campaign1
    })
  end
  let(:caller2a) do
    create(:caller, {
      account: admin.account,
      campaign: campaign2
    })
  end
  let(:caller2b) do
    create(:caller, {
      account: admin.account,
      campaign: campaign2
    })
  end
  let(:callers){ [caller1a, caller1b, caller2a, caller2b] }

  let(:first_row){ 'tr:first-of-type' }
  let(:first_cell){ 'td:first-of-type' }
  let(:last_row){ 'tr:last-of-type' }
  let(:last_cell){ 'td:last-of-type' }

  describe 'Managing Users & Accounts' do
    let(:main_table_css){ 'table' }

    before do
      create_list(:user, 3)
      http_login
      visit '/admin/users'
    end

    describe 'Force change customer account subscription to Trial or Enterprise' do
      it 'click "set account to enterprise" for the desired account row' do
        expect_current_subscription_to_eq 'Trial', 50
        set_account_to_manual
        expect_current_subscription_to_eq 'Enterprise', 0
      end

      it 'click "set account to trial" for the desired account row' do
        set_account_to_manual
        expect_current_subscription_to_eq 'Enterprise', 0
        set_account_to_trial
        expect_current_subscription_to_eq 'Trial', 50
      end
    end

    describe 'Update customer Per Minute rate' do
      context 'customer is on Enterprise (manual billing)' do
        let(:minutes_used){ 42 }
        before do
          expect_current_subscription_to_eq 'Trial', 50
          set_account_to_manual
          Quota.last.update_column(:minutes_pending, minutes_used)
          expect_current_subscription_to_eq 'Enterprise', minutes_used

          visit_subscription_page
        end
        context '"Reset to trial" is NOT checked' do
          it 'changes customer per minute rate and nothing else' do
            visit_subscription_page
            fill_in 'Price per minute', with: '.035'
            click_on 'Save'
            expect(page).to have_content 'Subscription updated.'
            expect(page).to have_content "Minutes used: #{minutes_used}"
          end
        end
        context '"Reset to trial" is checked' do
          it 'changes customer per minute rate and gives caller 50 minutes & 5 caller seats' do
            visit_subscription_page
            fill_in 'Price per minute', with: '.075'
            check 'Reset to trial'
            click_on 'Save'
            expect(page).to have_content 'Subscription updated.'
            expect(page).to have_content 'Current plan: Trial'
            expect(page).to have_content 'Minutes left: 50 of 50'
          end
        end
      end
    end

    describe 'Toggle dialer access for an account' do
      def deny_dialer_access
        account = User.last.account
        within(main_table_css) do
          within(last_row) do
            click_on "Deny Dialer"
          end
        end

        expect(page).to have_content "Dialer access denied for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Allow Dialer'
          end
        end
      end

      def allow_dialer_access
        account = User.last.account
        deny_dialer_access
        within(main_table_css) do
          within(last_row) do
            click_on 'Allow Dialer'
          end
        end

        expect(page).to have_content "Dialer access allowed for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Deny Dialer'
          end
        end
      end

      it 'click "Deny Dialer Access"' do
        deny_dialer_access
      end
      it 'click "Allow Dialer Access"' do
        allow_dialer_access
      end
    end

    describe 'Toggle Admin & Caller access for an account' do
      let(:deny_text){ "Deny All" }
      let(:allow_text){ "Allow All" }
      def deny_all_access
        account = User.last.account
        within(main_table_css) do
          within(last_row) do
            click_on deny_text
          end
        end

        expect(page).to have_content "Admin & dialer access denied for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content allow_text
          end
        end
      end

      def allow_all_access
        account = User.last.account
        deny_all_access
        within(main_table_css) do
          within(last_row) do
            click_on allow_text
          end
        end

        expect(page).to have_content "Admin & dialer access allowed for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content deny_text
          end
        end
      end

      it 'click "Deny All Access"' do
        deny_all_access
      end
      it 'click "Allow All Access"' do
        allow_all_access
      end
    end

    describe 'Toggle Abandonment between Fixed & Variable for an account' do
      let(:set_variable_text){ 'Set to Variable' }
      let(:set_fixed_text){ 'Set to Fixed' }
      let(:account){ User.last.account }

      it 'click "Set Abandonment to Variable"' do
        within(main_table_css) do
          within(last_row) do
            click_on set_variable_text
          end
        end

        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Set to Fixed'
          end
        end
      end

      it 'click "Set Abandonment to Fixed' do
        account.update_attributes!({abandonment: 'variable'})

        visit_users_page

        within(main_table_css) do
          within(last_row) do
            click_on set_fixed_text
          end
        end

        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Set to Variable'
          end
        end
      end
    end

    describe 'admin/state' do
      let(:main_table_css){ 'table tr td:first-of-type table' }
      before do
        callers[0..2].each do |caller|
          create(:caller_session, {
            on_call: 1,
            campaign: campaign1,
            caller: caller
          })
        end
        create(:caller_session, {
          on_call: 1,
          campaign: campaign2,
          caller: callers[3]
        })
        http_login
        visit '/admin/state'
      end

      it 'lists total number of logged in callers' do
        expect(page).to have_content 'Logged in callers: 4'
      end

      it 'lists total number of campaigns w/ logged in callers' do
        expect(page).to have_content 'Logged in campaigns: 2'
      end

      it 'lists campaigns w/ logged in callers' do
        within main_table_css do
          within "#{first_row} #{first_cell}" do
            expect(page).to have_content "login #{campaign1.name}"
          end
          within "#{last_row} #{first_cell}" do
            expect(page).to have_content "login #{campaign2.name}"
          end
        end
      end

      it 'links to allow login as a logged in caller' do
        within main_table_css do
          within "#{first_row} #{first_cell}" do
            click_link 'login'
          end
        end
        ['Dashboard', 'Active campaigns', 'Active callers'].each do |t|
          expect(page).to have_content t
        end
      end

      it 'lists number of callers on calls in each campaign' do
        within main_table_css do
          within "#{first_row} #{last_cell}" do
            expect(page).to have_content "Callers Number: #{campaign1.caller_sessions.count}"
          end
          within "#{last_row} #{last_cell}" do
            expect(page).to have_content "Callers Number: #{campaign2.caller_sessions.count}"
          end
        end
      end

      it 'links to inspect caller sessions' do
        within main_table_css do
          within "#{last_row} #{last_cell}" do
            click_link "Callers Number: #{campaign2.caller_sessions.count}"
          end
        end
        expect(page).to have_content campaign2.caller_sessions.first.caller.name
      end

      it 'provides a form to change the Twilio Limit' do
        fill_in 'Twilio Limit:', with: 2
        click_on 'Change'
      end
    end
  end
end
