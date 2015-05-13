require 'rails_helper'

describe 'Upload a recording', js: true, type: :feature do
  def upload_recording(file)
    fill_in 'Name', with: 'New Recording'
    attach_file 'recording_file', Rails.root.join('spec/fixtures/files/' + file)
    click_on 'Upload'
  end

  let(:user){ create(:user) }
  let(:account){ user.account }
  let!(:campaign) do
    create(:predictive, {
      account: account,
      use_recordings: true,           # force Message select to appear
      answering_machine_detect: true  #
    })
  end

  before do
    web_login_as(user)
    visit edit_client_campaign_path(campaign)
    click_on 'Add recording'
  end

  shared_examples 'all successful recording uploads' do
    it 'displays a success message' do
      expect(page).to have_content 'Voicemail added.'
    end

    it 'the new recording can be selected from the campaign form' do
      select 'New Recording', from: 'Message'
    end
  end

  context 'mp3 success' do
    before do
      upload_recording('recording.mp3')
    end

    it_behaves_like 'all successful recording uploads'
  end

  context 'wav success' do
    before do
      upload_recording('recording.wav')
    end

    it_behaves_like 'all successful recording uploads'
  end

  context 'aiff success' do
    before do
      upload_recording('recording.aiff')
    end

    it_behaves_like 'all successful recording uploads'
  end


  context 'no file selected' do
    before do
      fill_in 'Name', with: 'New Recording'
      click_on 'Upload'
    end
    it 'displays error' do
      expect(page).to have_content "File can't be blank"
    end
  end

  context 'must be wav, mp3/4, aif or aiff' do
    before do
      upload_recording('valid_voters_list.xlsx')
    end

    it 'displays error' do
      expect(page).to have_content 'Please upload an audio file encoded with one of WAV, MP3, or AIF.'
    end
  end

  context 'missing name' do
    before do
      attach_file 'recording_file', Rails.root.join('spec/fixtures/files/recording.mp3')
      click_on 'Upload'
    end
    it 'displays error' do
      expect(page).to have_content 'Name can\'t be blank'
    end
  end
end
