require 'rails_helper'

describe 'Add entries to Campaign', js: true, type: :feature, file_uploads: true do

  before(:all) do
    Capybara.javascript_driver = :selenium
  end

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
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

  it 'adds uploaded entries to the Campaign call list' do
    choose_list(csv_file_upload)
    fill_in 'List name', with: 'Munster cast'
    select 'Phone', from: 'Phone'
    select 'FirstName', from: 'FIRSTName'
    select 'LastName', from: 'LAST'
    select 'Email', from: 'Email'
    click_on 'Save & upload'

    process_pending_import_jobs
    visit edit_client_campaign_path(campaign)

    expect(page).to have_content 'Available to dial 2 100%'
    expect(page).to have_content 'Not dialed 2 100%'
  end
end
