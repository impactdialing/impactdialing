require 'rails_helper'

shared_context 'setup campaign' do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true)}
end

describe 'add caller', :type => :feature do
  include_context 'setup campaign'

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
  include_context 'setup campaign'
  let!(:caller){ create(:caller, campaign: campaign, account: account)}

  it 'gives proper notification when campaign is changed' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit edit_client_caller_path(caller)
    select '[None]', from: 'Campaign'
    click_on 'Save'
    expect(page).to have_content "Caller has been reassigned to a different campaign.
    The change has been submitted and it might take a few minutes to update."
  end

  it 'gives noticed when saved.' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit edit_client_caller_path(caller)
    fill_in 'Password', with: 'super_secret'
    click_on 'Save'
    expect(page).to have_content 'Changes saved.'
  end
end
