require 'spec_helper'

describe 'Client Web Dashboard (/client/index)' do
  before do
    create_user_and_login
  end

  context 'when a user is logged in' do
    it 'should be able to turn on Call Recording' do
      visit client_root_path

      click_on 'Turn call recording on'

      page.should have_content 'Call recording turned on.'
    end

    it 'should be able to turn off Call Recording' do
      account = User.last.account
      account.record_calls = true
      account.save!
      visit client_root_path

      click_on 'Turn call recording off'

      page.should have_content 'Call recording turned off.'
    end
  end
end
