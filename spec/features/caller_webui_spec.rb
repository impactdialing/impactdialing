require 'spec_helper'
include JSHelpers

describe 'Calling leads on a Preview campaign', type: :feature, caller_ui: true, e2e: true, js: true do
  let(:account){ create(:account) }
  let(:campaign) do
    create(:preview, {
      account: account
    })
  end
  let(:caller) do
    create(:caller, {
      campaign: campaign,
      password: 'password'
    })
  end
  before do
    caller_login_as(caller)
  end

  it 'page does not have account not funded error' do
    expect(page).not_to have_content 'Your account is not funded. Please contact your account administrator.'
  end

  it 'page has a lead info description' do
    expect(page).to have_content 'Lead information When connected, lead information will appear here.'
  end

  it 'page has a logout link' do
    click_on 'Log out'
    expect(page).to have_content 'Username'
    expect(page).to have_content 'Password'
    expect(page).to have_content 'Log in'
  end
end
