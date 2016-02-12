require 'rails_helper'
include JSHelpers

feature 'updating user roles', js: true do
  let(:user){ create(:user) }

  before do
    web_login_as(user)
    create(:user, {:account_id => user.account_id})
  end

  describe 'when a user role is changed ' do
    scenario 'from administrator to supervisor' do
      click_on "Account"
      select('Supervisor', :from => 'user_2_role')
      expect(page).to have_content 'Updated user role successfully.'
    end
  end
end
