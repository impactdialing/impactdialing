require 'spec_helper'
include JSHelpers

describe 'Calling leads on a Preview campaign', caller_ui: true, e2e: true, js: true do

  def caller_login_as(caller)
    visit '/app/login'
    fill_in 'Username', with: caller.username
    fill_in 'Password', with: caller.password
    click_on 'Log in'
  end

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

  it 'page has a contact info description' do
    page.should have_content 'Contact details Name, phone, address, etc will be listed here when connected.'
  end

  it 'page has a logout link' do
    click_on 'Logout'
    page.should have_content 'Username'
    page.should have_content 'Password'
    page.should have_content 'Log in'
  end
end
