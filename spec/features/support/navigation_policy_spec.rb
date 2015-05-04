require 'rails_helper'
require 'navigation_policy'

shared_examples 'the navigation authorization policy' do
  let(:supervisor) { create(:user, {role: 'supervisor'}) }
  let(:admin) { create(:user) }
  let(:path) { send("client_" + option + "_path") }

  describe 'the authorization policy' do
    it 'disallows access to supervisor' do
      web_login_as(supervisor)
      visit path
      expect(page).to have_content 'Only an administrator can access this page.'
    end

    it 'allows access to administrator' do
      web_login_as(admin)
      visit path
      expect(page).to have_content "View archived " + option
    end
  end
end


describe NavigationPolicy do
  describe 'navigation access' do
    describe 'when visiting the scripts page' do
      let(:option) { "scripts" }

      it_behaves_like 'the navigation authorization policy'
    end

    describe 'when visiting the campaign page' do
      let(:option) { "campaigns" }

      it_behaves_like 'the navigation authorization policy'
    end

    describe 'when visiting the caller page' do
      let(:option) { "callers" }

      it_behaves_like 'the navigation authorization policy'
    end
  end
end
