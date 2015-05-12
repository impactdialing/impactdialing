require 'rails_helper'

describe 'Upload', js: true, type: :feature do
  def upload_list(file)
    attach_file 'upload_datafile', Rails.root.join('spec/fixtures/files/' + file)
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
      upload_list('malformed.csv')
      expect(page).to have_content(I18n.t('activerecord.errors.models.csv.malformed'))
    end
  end
  context 'voter list with' do

    context 'no content' do
      it 'generates proper error message' do
        upload_list('voter_list_empty.csv')
        expect(page).to have_content(I18n.t('activerecord.errors.models.csv.missing_header_or_rows'))
      end
    end

    context 'only headers' do
      it 'generates proper error message' do
        upload_list('voter_list_only_headers.csv')
        expect(page).to have_content(I18n.t('activerecord.errors.models.csv.missing_header_or_rows'))
      end
    end

    context 'no headers' do
      it 'generates proper error message' do
        upload_list('voters_with_no_header_info.csv')
        expect(page).to have_content(I18n.t('activerecord.errors.models.csv.missing_header_or_rows'))
      end
    end

    context 'duplicate header names' do
      it 'generates proper error message' do
        upload_list('valid_voters_duplicate_phone_headers.csv')
        expect(page).to have_content(I18n.t('activerecord.errors.models.csv.duplicate_headers', :duplicate_headers => "PHONENUMBER"))
      end
    end

    context 'only headers and duplicate header names' do
      it 'generates proper error message' do
        upload_list('valid_voters_duplicate_phone_headers.csv')
        expect(page).to have_content(I18n.t('activerecord.errors.models.csv.missing_header_or_rows'), I18n.t('activerecord.errors.models.csv.duplicate_headers', :duplicate_headers => "PHONENUMBER"))
      end
    end
  end
end
