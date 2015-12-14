require 'rails_helper'

describe 'Restore archived callers successfully' do
  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:caller){ create(:caller, account: account) }
  before do
    caller.update_attribute(:active, false)
    web_login_as(user)
    visit client_callers_path
    click_on 'View archived callers'
  end
  it 'click "Restore" on the desired script listed in archived callers page' do
    click_on 'Restore'
    expect(page).to have_content 'Caller restored'
  end
end
