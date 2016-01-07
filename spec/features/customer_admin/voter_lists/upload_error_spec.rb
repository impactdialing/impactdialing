require 'rails_helper'

feature 'Upload', js: true, sauce: ENV['USE_SAUCE'].present? do
  include_context 'voter csv import'

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

  context 'voter list' do

    context 'malformed csv file' do
      it 'should display malformed csv error message' do
        upload_list('malformed.csv')
        expect(page).to have_content(I18n.t('csv_validator.malformed'))
      end
    end

    context 'csv has no content' do
      it 'should display no content error message' do
        upload_list('voter_list_empty.csv')
        expect(page).to have_content(I18n.t('csv_validator.missing_header_or_rows'))
      end
    end

    context 'csv only has headers' do
      it 'should display missing header or rows error message' do
        upload_list('voter_list_only_headers.csv')
        expect(page).to have_content(I18n.t('csv_validator.missing_header_or_rows'))
      end
    end

    context 'csv has no headers' do
      it 'should display missing header or rows error message' do
        upload_list('voters_with_no_header_info.csv')
        expect(page).to have_content(I18n.t('csv_validator.missing_header_or_rows'))
      end
    end

    context 'duplicate header names' do
      it 'should display duplicate header error message' do
        upload_list('valid_voters_duplicate_phone_headers.csv')
        expect(page).to have_content(I18n.t('csv_validator.duplicate_headers', :duplicate_headers => "PHONENUMBER"))
      end
    end

    context 'only headers and duplicate header names' do
      it 'should display both duplicate header and missing header or rows error messages' do
        upload_list('voter_list_only_headers_with_duplicates.csv')
        expect(page).to have_content(I18n.t('csv_validator.duplicate_headers', :duplicate_headers => "PHONENUMBER"))
        expect(page).to have_content(I18n.t('csv_validator.missing_header_or_rows'))
      end
    end
  end
end
