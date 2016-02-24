require 'rails_helper'

feature 'Manage Campaign call list', js: true, sauce: ENV['USE_SAUCE'].present?, file_uploads: true do

  def pall
    redis.keys('*').each do |key|
      type = redis.type(key)
      p "#{key} => #{type}"
      if type == 'zset'
        p "#{redis.zrange(key, 0, -1, with_scores: true)}"
      elsif type == 'hash'
        p "#{redis.hgetall(key)}"
      end
    end
  end

  before(:all) do
    Capybara.javascript_driver = :selenium unless ENV['USE_SAUCE'].present?
  end

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
    let(:csv_file_remove_numbers_upload) do
      cp_tmp('valid_list_remove_numbers.csv')
    end
    let(:csv_file_remove_leads_upload) do
      cp_tmp('valid_list_remove_leads.csv')
    end

    def choose_and_upload_list(file, list_name, option=nil, phone_only=false, map_id=false, reload=true)
      click_link 'Upload'
      choose_list(file)
      fill_in 'List name', with: list_name
      select 'Phone', from: 'Phone'
      unless phone_only
        select "(Discard this column)", from: 'ID'
        select 'FirstName', from: 'FIRSTName'
        select 'LastName', from: 'LAST'
        select 'Email', from: 'Email'
      end
      if map_id
        select 'ID', from: 'ID'
      end
      #save_and_open_page
      choose option || upload_option if campaign.voter_lists.count > 0
      click_button 'Upload'

      process_pending_import_jobs

      if reload
        visit edit_client_campaign_path(campaign)
        click_link 'List'
      end
    end
  end

  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:campaign) do
    create(:predictive, {
      account: account
    })
  end

  def login_and_visit_uploads
    web_login_as(user)
    visit edit_client_campaign_path(campaign)
    click_link 'Upload'
  end

  context 'when "Add to call list" is selected' do
    let(:upload_option){ "Add to call list" }
    before do
      login_and_visit_uploads
      click_link 'List'
      expect(page).to have_content "Available to dial 0 (0%)"
    end
    it 'adds uploaded entries to the Campaign call list' do
      choose_and_upload_list(csv_file_upload, 'Munsters cast')
      expect(page).to have_content 'Available to dial 2 (100%)'
      expect(page).to have_content 'Not dialed 2 (100%)'
      click_link 'Upload'
      expect(page).to have_content "Munsters cast Added 2 households and 3 leads"
    end
  end

  context 'when "Remove phone numbers from call list"' do
    let(:upload_option){ 'Remove phone numbers from call list' }
    before do
      login_and_visit_uploads
      choose_and_upload_list(csv_file_upload, 'Munsters cast', 'Add to call list')
      click_link 'List'
      expect(page).to have_content 'Available to dial 2 (100%)'
      click_link 'Upload'
    end
    it 'removes uploaded entries from the Campaign call list' do
      choose_and_upload_list(csv_file_remove_numbers_upload, 'Munsters retired cast', nil, true)
      click_link 'List'
      expect(page).to have_content 'Available to dial 0'
      expect(page).to have_content 'Not available to dial 0'
      click_link 'Upload'
      expect(page).to have_content "Munsters retired cast Removed 2 households"
    end
  end

  context 'when "Remove leads from call list"' do
    let(:upload_option){ 'Remove leads from call list' }

    context 'custom_id mapping is available' do
      before do
        login_and_visit_uploads
        choose_and_upload_list(csv_file_upload, 'Munsters cast', 'Add to call list', nil, true)
        click_link 'List'
        expect(page).to have_content 'Available to dial 2 (100%)'
        click_link 'Upload'
      end
      it 'removes uploaded leads from Campaign call list' do
        choose_and_upload_list(csv_file_remove_leads_upload, 'Munsters extras', nil, nil, true)
        click_link 'List'
        expect(page).to have_content 'Available to dial 1'
        expect(page).to have_content 'Not available to dial 0'
        click_link 'Upload'
        expect(page).to have_content "Munsters extras Removed 1 household and 2 leads"
      end
      it 'displays an error if the custom_id is not mapped' do
        choose_and_upload_list(csv_file_remove_leads_upload, 'Munsters double extras', nil, nil, false, false)
        expect(page).to have_content I18n.t('activerecord.errors.models.voter_list.custom_id_map_required')
      end
    end

    context 'custom_id mapping is not available' do
      before do
        login_and_visit_uploads
        choose_and_upload_list(csv_file_upload, 'Munsters cast', 'Add to call list', nil, false)
        click_link 'List'
        expect(page).to have_content 'Available to dial 2 (100%)'
      end
      it 'the option to remove leads from list is disabled' do
        click_link 'Upload'
        expect(page).to_not have_field upload_option
      end
    end
  end
end
