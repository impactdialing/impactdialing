require 'rails_helper'

describe 'Inviting users', type: :feature, admin: true do
  let(:admin){ create(:user) }

  before do
    web_login_as(admin)
    click_link 'Account'
  end

  context 'valid data submitted' do
    it 'displays success message' do
      fill_in 'Email', with: 'joe@test.com'
      click_on 'Invite'
      expect(page).to have_content 'joe@test.com has been invited.'
    end
  end

  context 'invalid data submitted for invite' do
    it 'displays error message' do
      fill_in 'Email', with: 'nonsense'
      click_on 'Invite'
      expect(page).to have_content "Email is invalid"
    end
  end
end

