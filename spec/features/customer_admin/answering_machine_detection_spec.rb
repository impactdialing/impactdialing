require 'spec_helper'

describe 'Answering Machine Detection', type: :feature, js: true, admin: true do
  def save_campaign(campaign, field, value)
    click_button 'Save'
    visit edit_client_campaign_path(campaign)
    el = page.find("##{field}")
    if value == '1' or value == '0'
      if value == '1'
        expect(el).to be_checked
      else
        expect(el).not_to be_checked
      end
    elsif value == 'true' or value == 'false'
      expect(el.value).to eq value
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
      it 'select "Drop message" and selecting a recording to auto-drop' do
        select "Drop message", from: "When a machine is detected"
        save_campaign(campaign, 'campaign_use_recordings', 'true')
      end
      it 'select "Hang-up" not auto-drop a recording' do
        select "Hang-up", from: "When a machine is detected"
        save_campaign(campaign, 'campaign_use_recordings', 'false')
      end

      context "Calling back after leaving a message" do
        before do
          select "Drop message", from: "When a machine is detected"
        end
        it 'is enabled by choosing "Call back after leaving message"' do
          select "Call back", from: "After a message is dropped"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', 'true')
        end
        it 'is disabled by choosing "Do not call back after dropping message"' do
          select "Do not call back", from: "After a message is dropped"
          save_campaign(campaign, 'campaign_call_back_after_voicemail_delivery', 'false')
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
    end
  end
end
