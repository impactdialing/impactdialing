require 'rails_helper'

describe 'add caller', :type => :feature do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true) }

  before do
    account.billing_subscription.update_attributes!(plan: 'basic')
  end

  it 'creates a valid caller and assigns them to a campaign' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit '/client/callers'
    click_on 'Add new caller'
    fill_in 'Username (no spaces)', with: 'someguy'
    fill_in 'Password', with: 'secret'
    select campaign.name, from: 'Campaign'
    click_on 'Save'

    expect(page).to have_content 'Caller saved'
    expect(page).to have_content 'Displaying 1 caller'
    expect(page).to have_content 'someguy'
  end

  it 'generates correct error when Username field is blank' do
    web_login_as(admin)
    visit '/client/callers'
    click_on 'Add new caller'
    click_on 'Save'

    expect(page).to have_content "Username can't be blank"
  end
end

describe 'edit caller', :type => :feature do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true) }
  let(:caller){ create(:caller, campaign: campaign, account: account) }

  before do
    account.billing_subscription.update_attributes!(plan: 'basic')
  end
