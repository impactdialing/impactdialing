require 'spec_helper'

describe 'Internal Admin pages' do
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

  describe 'Upgrade a user to Enterprise (Manual)' do
    let(:main_table_css){ 'table' }

    def set_account_to_manual
      visit '/admin/users'
      account = User.last.account
      within(main_table_css) do
        within(last_row) do
          click_on 'set account to manual'
        end
      end

      page.should have_content "Account##{account.id} successfully upgraded to Enterprise."
    end

    def expect_current_subscription_to_eq type, minutes
      within(main_table_css) do
        within(last_row) do
          click_on User.last.email
        end
      end
      click_on 'Account'
      click_on 'Billing'

      page.should have_content "Your current plan is #{type}."
      page.should have_content "Minutes left: #{minutes}"
    end

    before do
      create_list(:user, 3)
      http_login
      visit '/admin/users'
    end

    it 'click "set account to manual" for the desired user row' do
      set_account_to_manual
    end

    it 'subscriptions/index displays Enterprise and 0 minutes available' do
      expect_current_subscription_to_eq 'Trial', 50

      set_account_to_manual

      expect_current_subscription_to_eq 'Enterprise', 0
    end

    describe 'when disaster strikes' do
      let(:account){ User.last.account }
      let(:subscription){ account.current_subscription }

      describe 'old or new subscription fails to save' do
        it 'display msg that upgrade failed' do
          User.connection.execute("UPDATE subscriptions set number_of_callers=0 where id='#{subscription.id}';")
          within(main_table_css) do
            within(last_row) do
              click_on 'set account to manual'
            end
          end

          msg = "Upgrade to Enterprise failed "
          page.should have_content msg
          page.should have_content User.last.email
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
      page.should have_content 'Logged in callers: 4'
    end

    it 'lists total number of campaigns w/ logged in callers' do
      page.should have_content 'Logged in campaigns: 2'
    end

    it 'lists campaigns w/ logged in callers' do
      within main_table_css do
        within "#{first_row} #{first_cell}" do
          page.should have_content "login #{campaign1.name}"
        end
        within "#{last_row} #{first_cell}" do
          page.should have_content "login #{campaign2.name}"
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
        page.should have_content t
      end
    end

    it 'lists number of callers on calls in each campaign' do
      within main_table_css do
        within "#{first_row} #{last_cell}" do
          page.should have_content "Callers Number: #{campaign1.caller_sessions.count}"
        end
        within "#{last_row} #{last_cell}" do
          page.should have_content "Callers Number: #{campaign2.caller_sessions.count}"
        end
      end
    end

    it 'links to inspect caller sessions' do
      within main_table_css do
        within "#{last_row} #{last_cell}" do
          click_link "Callers Number: #{campaign2.caller_sessions.count}"
        end
      end
      page.should have_content campaign2.caller_sessions.first.caller.name
    end

    it 'provides a form to change the Twilio Limit' do
      fill_in 'Twilio Limit:', with: 2
      click_on 'Change'
    end
  end
end