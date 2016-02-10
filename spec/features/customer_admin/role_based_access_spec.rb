require 'rails_helper'

describe 'Access based on User#role value (administrator or supervisor)', type: :feature, reports: true do
  shared_examples_for 'all roles' do
    it 'can access the dashboard' do
      visit '/client'
      expect(page).to have_content 'Dashboard'
      expect(page).to have_content 'Active campaigns'
      expect(page).to have_content 'Active callers'
    end
    it 'can view reports' do
      create(:campaign, account: user.account)
      create(:caller, account: user.account)
      visit '/client/reports'
      expect(page).to have_content 'Reports'
      expect(page).to have_content 'Campaign reports'
      expect(page).to have_content 'Caller reports'
      expect(page).to have_content 'Account-wide reports'
    end
  end
  context 'User#role = administrator' do
    let(:user){ create(:user, role: User::Role::ADMINISTRATOR) }
    before do
      web_login_as(user)
    end
    it_behaves_like 'all roles'
    it 'can manage scripts' do
      visit '/client/scripts'
      expect(page).to have_content 'Add new script'
    end
    it 'can manage campaigns' do
      visit '/client/campaigns'
      expect(page).to have_content 'Add new campaign'
    end
    it 'can manage callers' do
      visit '/client/callers'
      expect(page).to have_content 'Add new caller'
    end
  end

  context 'User#role = supervisor' do
    let(:user){ create(:user, role: User::Role::SUPERVISOR) }
    let(:error_msg){ I18n.t('admin_access') }
    before do
      web_login_as(user)
    end
    it_behaves_like 'all roles'
    it 'cannot manage scripts' do
      visit '/client/scripts'
      expect(page).to have_content error_msg
      expect(current_path).to eq '/client'
    end
    it 'cannot manage campaigns' do
      visit '/client/campaigns'
      expect(page).to have_content error_msg
      expect(current_path).to eq '/client'
    end
    it 'cannot manage callers' do
      visit '/client/callers'
      expect(page).to have_content error_msg
      expect(current_path).to eq '/client'
    end
  end
end
