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

  it 'is enabled by checking "Auto-detect whether human or machine answers a call"' do
    check "Auto-detect whether human or machine answers a call"
    save_campaign(campaign, 'campaign_answering_machine_detect', '1')
  end
  it 'is disabled by unchecking "Auto-detect whether human or machine answers a call"' do
    uncheck "Auto-detect whether human or machine answers a call"
    save_campaign(campaign, 'campaign_answering_machine_detect', '0')
  end

  context 'Leaving messages' do
    context 'Answering machine detection is enabled' do
      before do
        check "Auto-detect whether human or machine answers a call"
      end
      it 'choose "Drop recorded message" and selecting a recording to auto-drop' do
        choose "Drop recorded message"
        save_campaign(campaign, 'campaign_use_recordings_true', '1')
      end
      it 'choose "Hang-up" not auto-drop a recording' do
        choose "Hang-up"
        save_campaign(campaign, 'campaign_use_recordings_true', '0')
      end

      context "Calling back after leaving a message" do
        before do
          choose "Drop recorded message"
        end
        it 'is enabled by checking "Call back after leaving message"' do
          check "Call back after dropping message BUT drop only one message"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '1')
        end
        it 'is disabled by unchecking "Call back after leaving message"' do
          uncheck "Call back after dropping message BUT drop only one message"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '0')
        end
      end
    end

    context 'Caller can drop message manually' do
      before do
        check "Callers can click to drop recorded message"
      end
      it 'choose "Callers can click to drop recorded message" and selecting a recording to auto-drop' do
        save_campaign(campaign, 'campaign_caller_can_drop_message_manually', '1')
      end

      context "Calling back after leaving a message" do
        it 'is enabled by checking "Call back after leaving message"' do
          check "Call back after dropping message BUT drop only one message"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '1')
        end
        it 'is disabled by unchecking "Call back after leaving message"' do
          uncheck "Call back after dropping message BUT drop only one message"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', '0')
        end
      end
    end
  end
end
