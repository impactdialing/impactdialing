require 'rails_helper'
include FakeCallData

  describe 'Switch campaign and update range' do
    describe 'Caller Usage Report', type: :feature, rack: true do

      let(:admin) do
        create(:user)
      end

      before do
        @script = create(:script)
        @account  = admin.account
        @caller = create(:caller, account: @account, created_at:3.days.ago)
        @campaign1 = create(:bare_preview, script: @script, account: @account)
        @campaign2 = create(:bare_preview, script: @script, account: @account)
        @caller_session1 = create(:caller_session, campaign: @campaign1, caller: @caller, created_at:2.days.ago, tDuration:60)
        @caller_session2 = create(:caller_session, campaign: @campaign2, caller: @caller, created_at:Time.now, tDuration:120)
      end

      before do
        web_login_as(admin)
        visit usage_client_caller_path(@caller)
      end

      context 'Switch campaign' do
        it 'allows a user to view different campaigns a caller has worked on' do
          select @campaign2.name, from: 'campaign_id'
          click_on 'Switch campaign'
          expect(page).to have_content "#{@campaign2.name}"
        end
      end

      context 'Update date range' do
        it 'should start with proper date' do
          within('#utilization') do
            expect(page).to have_content 'Connected (total)	3'
          end
        end

        it 'allows a user to update date range' do
          fill_in 'from_date', with: Date.today.strftime('%m/%d/%Y')
          fill_in 'to_date', with: Date.today.strftime('%m/%d/%Y')
          click_on 'Update date range'
          within('#utilization') do
            expect(page).to have_content 'Connected (total)	2'
          end
        end

        it 'creates an error message when from field has invalid data range' do
          fill_in 'to_date', with: ''
          click_on 'Update date range'
          expect(page).to have_content "Date must be of format mm/dd/yyyy; eg 7/4/2014"
        end

    end
  end

  describe 'Fake data stuff' do
    describe 'Caller Usage Report', type: :feature, rack: true do

      let(:admin) do
        create(:user)
      end

      before do
        @script2 = create(:script)
        @account2  = admin.account
        @caller2 = create(:caller, account: @account2, created_at:3.days.ago)
        @campaign3 = create_campaign_with_script(:bare_preview, @account2).last
        @campaign4 = create_campaign_with_script(:bare_preview, @account2).last
        @caller_session3 = create(:caller_session, campaign: @campaign3, caller: @caller2, created_at:2.days.ago, tDuration:60)
        @caller_session4 = create(:caller_session, campaign: @campaign4, caller: @caller2, created_at:Time.now, tDuration:120)
        @caller_session5 = create(:caller_session, campaign: @campaign3, caller: @caller2, created_at:1.days.ago, tDuration:60)
        create(:bare_call_attempt, :completed, caller: @caller2, campaign: @campaign3)
        create(:phones_only_caller_session, campaign: @campaign3, caller: @caller2, caller_type: CallerSession::CallerType::PHONE, tStatus:'completed', created_at:1.days.ago, tDuration:60, tEndTime: Time.now)
      end

      before do
        web_login_as(admin)
        visit usage_client_caller_path(@caller2)
      end

      it 'shows utilization stuff' do
save_and_open_page
        within('#utilization') do
          expect(page).to have_content  'On call 1'
          expect(page).to have_content  'Wrap up 2'
          expect(page).to have_content  'On hold 3'
          expect(page).to have_content  'Connected (total)	5'
        end
      end

      it 'shows billable time stuff' do
        within('#billable_time') do
          expect(page).to have_content 'Caller 1'
          expect(page).to have_content 'Leads 1'
          expect(page).to have_content 'Total 2'
        end
      end

    end
  end

end
