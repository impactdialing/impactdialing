require 'rails_helper'

describe 'twiml/caller_sessions/identify' do
  let(:path){ 'twiml/caller_sessions/identify' }
  let(:action_params) do
    {
      session_id: caller_session.id,
      protocol: 'http://',
      host: Settings.twilio_callback_host,
      port: Settings.twilio_callback_port
    }
  end

  context 'caller is phones only' do
    let(:caller_record){ create(:caller, is_phones_only: true) }
    let(:caller_session) do
      create(:phones_only_caller_session, {
        caller: caller_record,
        campaign: caller_record.campaign
      })
    end

    before do
      assign(:caller_record, caller_record)
      assign(:caller_session, caller_session)

      render template: path
    end

    it 'reads I18n dialer.twiml.caller.instruction_choice' do
      gather_options = {
        numDigits: 1,
        timeout: 10,
        action: read_instruction_options_caller_url(caller_record.id, action_params),
        method: 'POST',
        finishOnKey: '5'
      }
      expect(rendered).to gather(gather_options).with_nested_say(I18n.t(:caller_instruction_choice))
    end
  end

  context 'caller is using a browser' do
    let(:caller_record){ create(:caller, is_phones_only: false) }
    let(:caller_session) do
      create(:webui_caller_session, {
        caller: caller_record,
        campaign: caller_record.campaign
      })
    end

    before do
      assign(:caller_record, caller_record)
      assign(:caller_session, caller_session)

      render template: path
    end
    it 'plays hold music' do
      dial_options = {
        hangupOnStar: true,
        action: pause_caller_url(caller_record.id, action_params)
      }
      conference_options = {
        startConferenceOnEnter: false,
        endConferenceOnExit: true,
        beep: true,
        waitUrl: HOLD_MUSIC_URL,
        waitMethod: 'GET'
      }

      expect(rendered).to dial_conference(dial_options, conference_options)
    end
  end
end
