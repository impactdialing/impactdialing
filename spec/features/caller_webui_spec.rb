require 'spec_helper'
include JSHelpers

describe 'Calling leads on a Preview campaign', caller: true, e2e: true do
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
    page.should_not have_content 'Your account is not funded. Please contact your account administrator.'
  end

  it 'page has a lead info description' do
    page.should have_content 'Lead information When connected, lead information will appear here.'
  end

  it 'page has a logout link' do
    click_on 'Log out'
    page.should have_content 'Username'
    page.should have_content 'Password'
    page.should have_content 'Log in'
  end
end
