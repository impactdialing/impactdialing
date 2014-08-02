require 'spec_helper'

describe 'Caller Management', :type => :feature do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true) }

  context 'Basic subscriptions' do
    before do
      account.billing_subscription.update_attributes!(plan: 'basic')
    end

    it 'can create callers and assign them to a campaign' do
      expect(account.campaigns).to include(campaign)
      web_login_as(admin)
      visit '/client/callers'
      click_on 'Add new caller'
      fill_in 'Username (no spaces)', with: 'someguy'
      fill_in 'Password', with: 'secret'
      select campaign.name, from: 'Campaign'
      click_on 'Save'

      expect(page).to have_content 'Caller saved'
      expect(page).to have_content 'Displaying 1 Caller'
      expect(page).to have_content 'someguy'
    end
  end
end
