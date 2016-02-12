require 'rails_helper'

shared_context 'setup campaign' do
  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create(:power, account: account, active: true)}
end

feature 'add caller', admin: true do
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

feature 'edit caller', admin: true do
  include_context 'setup campaign'
  let!(:caller){ create(:caller, campaign: campaign, account: account)}

  it 'gives notice a when caller is assigned to a different campaign' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit edit_client_caller_path(caller)
    select '[None]', from: 'Campaign'
    click_on 'Save'
    expect(page).to have_content I18n.t('activerecord.successes.models.caller.reassigned')
  end

  it 'gives a different notice when a caller is saved and the campaign has not been changed' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit edit_client_caller_path(caller)
    fill_in 'Password', with: 'super_secret'
    click_on 'Save'
    expect(page).to have_content 'Caller saved.'
  end

  it 'throws proper error message when nothing is entered for caller name.' do
    expect(account.campaigns).to include(campaign)
    web_login_as(admin)
    visit edit_client_caller_path(caller)
    fill_in 'Username (no spaces)', with: ''
    click_on 'Save'
    expect(page).to have_content "Username can't be blank"
  end
end
