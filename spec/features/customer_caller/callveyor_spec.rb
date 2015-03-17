require 'spec_helper'
include JSHelpers

describe 'Calling leads on a Preview campaign', type: :feature, caller_ui: true, e2e: true, js: true do

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
    expect(page).to have_content 'Contact details Name, phone, address, etc will be listed here when connected.'
  end

  it 'page has a logout link' do
    click_on 'Logout'
    expect(page).to have_content 'Username'
    expect(page).to have_content 'Password'
    expect(page).to have_content 'Log in'
  end
end
