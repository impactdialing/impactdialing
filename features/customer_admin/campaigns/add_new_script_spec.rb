require 'rails_helper'

feature 'include a "add a new script" link' do

  let(:admin) { create(:user) }

# it would be nice if the 'Add new campaign button' is disabled.
  describe 'adding a new campaign page' do
    it 'adds a link to new_script_path if there are no scripts' do
      web_login_as(admin)
      visit client_campaigns_path
      expect(page).to have_content 'add a new script'
    end

# the new_script_path link is hidden.
    it 'does not add a link to new_script_path if there is a script' do
      web_login_as(admin)
      create(:script, account: admin.account)
      visit client_campaigns_path
      expect(page).not_to have_content 'add a new script'
    end
  end
end
