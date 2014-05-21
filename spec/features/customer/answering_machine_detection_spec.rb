require 'spec_helper'

describe 'Answering Machine Detection', js: true, admin: true do
  def save_campaign(campaign, field, value)
    click_button 'Save'
    visit edit_client_campaign_path(campaign)
    checkbox = page.find("##{field}")
    if value == '1'
      checkbox.should be_checked
    else
      checkbox.should_not be_checked
    end
  end

  let(:admin) do
    create(:user)
  end
  let(:recording) do
    create(:recording)
  end
  let(:campaign) do
    create(:power, {
      account: admin.account
    })
  end
  before do
    a = admin.account
    # recording.account_id = a.id
    # recording.save!
    a.recordings << recording
    a.save!
    web_login_as(admin)
    visit edit_client_campaign_path(campaign)
  end

  it 'is enabled by checking "Automatically detect answering machines"' do
    check "Automatically detect answering machines"
    save_campaign(campaign, 'campaign_answering_machine_detect', '1')
  end
  it 'is disabled by unchecking "Automatically detect answering machines"' do
    uncheck "Automatically detect answering machines"
    save_campaign(campaign, 'campaign_answering_machine_detect', '0')
  end

  context 'Leaving messages' do
    before do
      check "Automatically detect answering machines"
    end
    it 'is enabled by checking "Leave messages" and selecting a recording to drop' do
      check "Leave messages"
      save_campaign(campaign, 'campaign_use_recordings', '1')
    end
    it 'is disabled by unchecking "Leave messages"' do
      uncheck "Leave messages"
      save_campaign(campaign, 'campaign_use_recordings', '0')
    end

    context "Calling back after leaving a message" do
      before do
        check "Leave messages"
      end
      it 'is enabled by checking "Call back after leaving message"' do
        check "Call back after leaving message BUT leave only one message"
        save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '1')
      end
      it 'is disabled by unchecking "Call back after leaving message"' do
        uncheck "Call back after leaving message BUT leave only one message"
        save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '0')
      end
    end
  end
end