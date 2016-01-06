require 'rails_helper'

feature 'creating new campaigns', js: true, sauce: ENV['USE_SAUCE'].present? do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:script) do
    create_campaign_with_script(:preview, account).first
  end
  before do
    create(:recording, account: account)
    script
    web_login_as(admin)
    visit new_client_campaign_path
  end
  context 'Power' do
    it 'accepts General and Message settings in the first save' do
      fill_in 'Name', with: 'ui-awesome'
      fill_in 'Caller ID', with: '5555551234'
      select script.name, from: 'Script'
      select 'Power', from: 'Dialing mode'
      select '(GMT-07:00) Arizona', from: 'Time zone'
      fill_in 'Hours between redials', with: '12'

      click_link 'Messages'
      using_wait_time(60) do
        check 'Auto-detect whether human or machine answers a call'
        check 'Callers can click to drop recorded message after a call is answered'
      end

      click_button 'Save'

      expect(page).to have_content 'Campaign saved'
      visit edit_client_campaign_path(Campaign.last)

      expect(page).to have_selector "input[value='ui-awesome']"
      expect(page).to have_selector "input[value='5555551234']"

      click_link 'Messages'
      within('label[for="campaign_answering_machine_detect"]') do
        expect(page).to have_selector 'input[checked="checked"]'
      end
      within('label[for="campaign_caller_can_drop_message_manually"]') do
        expect(page).to have_selector 'input[checked="checked"]'
      end
    end
  end
end
