require 'rails_helper'

feature 'Restore archived scripts successfully' do
  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:script){ create(:script, account: account) }
  before do
    script.update_attribute(:active, false)
    web_login_as(user)
    visit client_scripts_path
    click_on 'View archived scripts'
  end
  scenario 'click "Restore" on the desired script listed in archived scripts page' do
    click_on 'Restore'
    expect(page).to have_content 'Script restored'
  end
end
