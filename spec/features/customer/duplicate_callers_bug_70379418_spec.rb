require 'spec_helper'

describe 'Caller Management' do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true) }

  let(:admin2){ create(:user) }
  let(:account2){ admin2.account }
  let(:campaign2){ create(:preview, account: account2, active: true)}

  def create_caller(username, campaign)
    visit '/client/callers'
    click_on 'Add new caller'
    fill_in 'Username (no spaces)', with: username
    fill_in 'Password', with: 'secret'
    select campaign.name, from: 'Campaign'
    click_on 'Save'
  end

  it 'can create callers and assign them to a campaign' do
    account.campaigns.should include(campaign)
    web_login_as(admin)

    create_caller('someguy', campaign)

    page.should have_content 'Caller saved'
    page.should have_content 'Displaying 1 Caller'
    page.should have_content 'someguy'

    click_on 'Log out'
    web_login_as(admin2)
    create_caller('Someguy', campaign2)
    page.should_not have_content 'Caller saved'
    page.should have_content 'Username has already been taken'
  end
end
