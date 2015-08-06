require 'rails_helper'

describe 'twiml/lead/answered.html.erb' do
  let(:campaign){ create(:preview) }
  let(:caller_session) do
    create(:bare_caller_session, :webui, {
      on_call: true,
      available_for_call: false,
      session_key: 'caller-session-key'
    })
  end
  let(:dialed_call) do
    double('CallFlow::Call::Dialed', {
      caller_session: caller_session,
      twiml_flag: :connect,
      record_calls: 'false',
      conference_name: caller_session.session_key
    })
  end

  before do
    assign(:dialed_call, dialed_call)
  end

  context '@twiml_flag = :connect' do
    it 'renders Conference twiml' do
      dial_options = {
        hangupOnStar: 'false',
        action: twiml_lead_disconnected_url({
          host: Settings.twilio_callback_host,
          protocol: 'http://'
        }),
        record: campaign.account.record_calls
      }
      conference_options = {
        name: caller_session.session_key,
        waitUrl: HOLD_MUSIC_URL,
        waitMethod: 'GET',
        beep: false,
        endConferenceOnExit: true
      }
      render template: 'twiml/lead/answered.html.erb'
      expect(rendered).to dial_conference(dial_options, conference_options)
    end
  end

  context '@twiml_flag = :leave_message' do
    let(:recording_url){ 'http://s3.amazon.com/recording.mp3' }
    before do
      allow(dialed_call).to receive(:twiml_flag){ :leave_message }
      allow(dialed_call).to receive(:recording_url){ recording_url }
    end
    it 'renders Play twiml' do
      render template: 'twiml/lead/answered.html.erb'
      expect(rendered).to play(recording_url)
    end
  end

  context '@twiml_flag = :hangup' do
    before do
      allow(dialed_call).to receive(:twiml_flag){ :hangup }
    end
    it 'renders Hangup twiml' do
      render template: 'twiml/lead/answered.html.erb'
      expect(rendered).to hangup
    end
  end
end

