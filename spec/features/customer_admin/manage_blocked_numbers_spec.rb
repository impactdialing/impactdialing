require 'spec_helper'

describe 'Blocked Number management', type: :feature, rack: true do
  let(:i18n_scope){ 'activerecord.errors.models.blocked_number' }
  let(:customer){ create(:user) }
  let!(:preview){ create(:preview, account: customer.account) }
  let!(:power){ create(:power, account: customer.account) }
  let!(:predictive){ create(:predictive, account: customer.account) }
  let(:number){ Forgery(:address).phone }
  before do
    I18n.locale = :en
    web_login_as(customer)
    visit client_campaigns_path
    click_on 'Manage Do Not Call list'
  end

  describe 'creating a blocked number' do
    def save_blocked_number(number, level)
      click_on 'Add'
      expect(page).to have_content I18n.t(:blocked_number_created, number: number.gsub(/[^\d]/, ''), level: level)
    end
    before do
      fill_in 'Number', with: number
    end
    it 'account-wide' do
      select 'System', from: 'Level'
      save_blocked_number(number, 'System')
    end

    it 'campaign-specific' do
      select Power.first.name, from: 'Level'
      save_blocked_number(number, Power.first.name)
    end
  end

  describe 'error creating a blocked number' do
    it 'requires number be < 16 characters' do
      number = Array.new(17, rand(9)).join
      fill_in 'Number', with: number
      click_on 'Add'
      expect(page).to have_content I18n.t(:too_long, scope: i18n_scope)
    end

    it 'requires number be >= 10 characters' do
      number = Array.new(9, rand(9)).join
      fill_in 'Number', with: number
      click_on 'Add'
      expect(page).to have_content I18n.t(:too_short, scope: i18n_scope)
    end

    it 'requires number contain only numbers, paranthesis or plus sign' do
      number = Array.new(5, '3b').join
      fill_in 'Number', with: number
      click_on 'Add'
      expect(page).to have_content I18n.t(:not_a_number, scope: i18n_scope)
    end

    it 'requires number be unique for associated account when creating account-wide number' do
      blocked_number = create(:blocked_number, number: number, account: customer.account)
      fill_in 'Number', with: number
      click_on 'Add'
      expect(page).to have_content I18n.t(:taken, scope: i18n_scope, value: number.gsub(/[^\d]/,''), level: 'System')
    end

    it 'requires number be unique for associated campaign when creating campaign-specific number' do
      blocked_number = create(:blocked_number, number: number, account: customer.account, campaign: power)
      fill_in 'Number', with: number
      select power.name, from: 'Level'
      click_on 'Add'
      expect(page).to have_content I18n.t(:taken, scope: i18n_scope, value: number.gsub(/[^\d]/,''), level: power.name)
    end
  end

  describe 'deleting a blocked number' do
    it 'account-wide' do
      blocked_number = create(:blocked_number, account: customer.account, number: number)
      visit blocked_numbers_path
      within("#blocked_number_#{blocked_number.id}") do
        click_link("Remove number from DNC")
      end
      expect(page).to have_content I18n.t(:blocked_number_deleted, number: number.gsub(/[^\d]/,''), level: 'System')
    end

    it 'campaign-specific' do
      blocked_number = create(:blocked_number, account: customer.account, campaign: preview, number: number)
      visit blocked_numbers_path
      within("#blocked_number_#{blocked_number.id}") do
        click_link("Remove number from DNC")
      end
      expect(page).to have_content I18n.t(:blocked_number_deleted, number: number.gsub(/[^\d]/,''), level: preview.name)
    end
  end
end
