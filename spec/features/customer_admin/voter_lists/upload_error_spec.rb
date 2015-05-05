require 'rails_helper'

describe 'Upload a list', js: true, type: :feature do
  def upload_list(path)
    attach_file 'upload_datafile', Rails.root.join(path)
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

  context 'malformed csv file' do
    it 'generates proper error message' do
      upload_list('spec/fixtures/files/malformed.csv')
      expect(page).to have_content(I18n.t(:csv_malformed))
    end
  end
  context 'voter list with' do

    context 'no content' do
      it 'generates proper error message' do
        upload_list('spec/fixtures/files/voter_list_empty.csv')
        expect(page).to have_content(I18n.t(:csv_has_no_header_data))
      end
    end

    context 'only headers' do
      it 'generates proper error message' do
        upload_list('spec/fixtures/files/voter_list_only_headers.csv')
        expect(page).to have_content(I18n.t(:csv_has_no_row_data))
      end
    end

    context 'no headers' do
      it 'generates proper error message' do
        upload_list('spec/fixtures/files/voters_with_no_header_info.csv')
        expect(page).to have_content(I18n.t(:csv_has_no_header_data))
      end
    end

    context 'duplicate header names' do
      it 'generates proper error message' do
        upload_list('spec/fixtures/files/valid_voters_duplicate_phone_headers.csv')
        expect(page).to have_content(I18n.t(:csv_duplicate_headers))
      end
    end

    context 'only headers and duplicate header names' do
      it 'generates proper error message' do
        upload_list('spec/fixtures/files/valid_voters_duplicate_phone_headers.csv')
        expect(page).to have_content(I18n.t(:csv_has_no_row_data), I18n.t(:csv_duplicate_headers))
      end
    end
  end
end
