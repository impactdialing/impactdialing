require 'rails_helper'

describe 'Add entries to Campaign', js: true, type: :feature, file_uploads: true do

  def pall
    re = Redis.new
    re.keys('*').each do |key|
      type = re.type(key)
      p "#{key} => #{type}"
      if type == 'zset'
        p "#{re.zrange(key, 0, -1, with_scores: true)}"
      elsif type == 'hash'
        p "#{re.hgetall(key)}"
      end
    end
  end

  before(:all) do
    Redis.new.flushall
    Capybara.javascript_driver = :selenium
  end

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
    let(:csv_file_remove_numbers_upload) do
      cp_tmp('valid_list_remove_numbers.csv')
    end

    def choose_and_upload_list(file, list_name, option=nil, phone_only=false)
      choose_list(file)
      fill_in 'List name', with: list_name
      select 'Phone', from: 'Phone'
      unless phone_only
        select "(Discard this column)", from: 'ID'
        select 'FirstName', from: 'FIRSTName'
        select 'LastName', from: 'LAST'
        select 'Email', from: 'Email'
      end
      #save_and_open_page
      choose option || upload_option
      click_on 'Upload'

      process_pending_import_jobs
      visit edit_client_campaign_path(campaign)
    end
  end

  let(:user){ create(:user) }
  let(:account){ user.account }
  let(:campaign) do
    create(:predictive, {
      account: account
    })
  end
  let(:datetime) do
    # hm, this will probably fail sporadically...
    Time.now.in_time_zone(campaign.time_zone).strftime('%b %e, %Y at %l:%M%P')
  end

  context 'when "Add to call list" is selected' do
    let(:upload_option){ "Add to call list" }
    before do
      web_login_as(user)
      visit edit_client_campaign_path(campaign)
      expect(page).to have_content "Available to dial 0 0%"
    end
    it 'adds uploaded entries to the Campaign call list' do
      choose_and_upload_list(csv_file_upload, 'Munsters cast')
      expect(page).to have_content 'Available to dial 2 100%'
      expect(page).to have_content 'Not dialed 2 100%'
      expect(page).to have_content "Munsters cast Added 2 Households and 3 Leads #{datetime}"
    end
  end

  context 'when "Remove phone numbers from call list"' do
    let(:upload_option){ 'Remove phone numbers from call list' }
    before do
      web_login_as(user)
      visit edit_client_campaign_path(campaign)
      choose_and_upload_list(csv_file_upload, 'Munsters cast', 'Add to call list')
      expect(page).to have_content 'Available to dial 2 100%'
    end
    it 'removes uploaded entries from the Campaign call list' do
      choose_and_upload_list(csv_file_remove_numbers_upload, 'Munsters retired cast', nil, true)
      expect(page).to have_content 'Available to dial 0'
      expect(page).to have_content 'Not available to dial 0'
      expect(page).to have_content "Munsters retired cast Removed 2 households #{datetime}"
    end
  end
end
