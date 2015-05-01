require 'rails_helper'
require 'navigation_policy'

feature 'the headless NavigationPolicy' do
  let(:supervisor) { create(:user, {role: 'supervisor'}) }
  let(:admin) { create(:user) }
  subject { NavigationPolicy }

  describe 'the authorization policy' do
    it 'disallows access to supervisor' do
      web_login_as(supervisor)
      visit client_scripts_path
      expect(page).to have_content 'Only an administrator can access this page.'
    end

    it 'allows access to administrator' do
      web_login_as(admin)
      visit client_scripts_path
      expect(page).to have_content 'View archived scripts'
    end
  end
end
