require 'spec_helper'

describe 'Internal Admin pages', type: :feature, admin: true do
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

    describe 'Toggle accounts between Trial & Enterprise (Manual)' do
      def set_account_to_manual
        visit '/admin/users'
        account = User.last.account
        within(main_table_css) do
          within(last_row) do
            click_on 'set account to enterprise'
          end
        end

        expect(page).to have_content "Account##{account.id} successfully upgraded to Enterprise."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'set account to trial'
          end
        end
      end

      def set_account_to_trial
        account = User.last.account
        set_account_to_manual
        within(main_table_css) do
          within(last_row) do
            click_on 'set account to trial'
          end
        end
        expect(page).to have_content "Account##{account.id} successfully downgraded to Trial."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'set account to enterprise'
          end
        end
      end

      def expect_current_subscription_to_eq type, minutes
        within(main_table_css) do
          within(last_row) do
            click_on User.last.email
          end
        end
        click_on 'Account'
        click_on 'Billing'

        expect(page).to have_content "Your current plan is #{type}."
        expect(page).to have_content "Minutes left: #{minutes}"
      end

      it 'click "set account to enterprise" for the desired account row' do
        expect_current_subscription_to_eq 'Trial', 50
        set_account_to_manual
        expect_current_subscription_to_eq 'Enterprise', 0
      end

      it 'click "set account to trial" for the desired account row' do
        set_account_to_trial
        expect_current_subscription_to_eq 'Trial', 50
      end
    end

    describe 'Toggle dialer access for an account' do
      def deny_dialer_access
        account = User.last.account
        within(main_table_css) do
          within(last_row) do
            click_on "Deny Dialer Access"
          end
        end

        expect(page).to have_content "Dialer access denied for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Allow Dialer Access'
          end
        end
      end

      def allow_dialer_access
        account = User.last.account
        deny_dialer_access
        within(main_table_css) do
          within(last_row) do
            click_on 'Allow Dialer Access'
          end
        end

        expect(page).to have_content "Dialer access allowed for Account##{account.id}."
        within(main_table_css) do
          within(last_row) do
            expect(page).to have_content 'Deny Dialer Access'
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
      let(:deny_text){ "Deny All Access" }
      let(:allow_text){ "Allow All Access" }
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
