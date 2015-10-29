require 'rails_helper'

describe 'Add entries to Campaign', js: true, type: :feature, file_uploads: true do

  before(:all) do
    Capybara.javascript_driver = :selenium
  end

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }

    def choose_and_upload_list(option=nil)
      choose_list(csv_file_upload)
      fill_in 'List name', with: 'Munsters cast'
      select 'Phone', from: 'Phone'
      select 'FirstName', from: 'FIRSTName'
      select 'LastName', from: 'LAST'
      select 'Email', from: 'Email'
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

  before do
    web_login_as(user)
    visit edit_client_campaign_path(campaign)
  end

  context 'when "Add to call list" is selected' do
    let(:upload_option){ "Add to call list" }
    it 'adds uploaded entries to the Campaign call list' do
      # hm, this will probably fail sporadically...
      datetime = Time.now.in_time_zone(campaign.time_zone).strftime('%b %e, %Y at %l:%M%P')
      choose_and_upload_list

      expect(page).to have_content 'Available to dial 2 100%'
      expect(page).to have_content 'Not dialed 2 100%'
      expect(page).to have_content "Munsters cast Added 2 Households and 3 Leads #{datetime}"
    end
  end
      expect(page).to have_content 'Available to dial 2 100%'
      expect(page).to have_content 'Not dialed 2 100%'
    end
  end
end
