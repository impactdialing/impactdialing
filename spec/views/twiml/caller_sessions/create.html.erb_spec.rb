require 'rails_helper'

describe 'twiml/caller_sessions/create.html.erb' do
  let(:campaign){ create(:predictive) }
  let(:caller){ create(:caller, campaign: campaign) }
  let(:caller_session){ create(:webui_caller_session, caller: caller, campaign: campaign, session_key: 'caller-session-key') }

  it 'renders Conference twiml' do
    assign(:caller, caller)
    assign(:caller_session, caller_session)
    render template: 'twiml/caller_sessions/create.html.erb'

    dial_options = {
      hangupOnStar: true,
      action: pause_caller_url(caller.id, {
        session_id: caller_session.id,
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: 'http://'
      })
    }
    conference_options = {
      name: caller_session.session_key,
      startConferenceOnEnter: false,
      endConferenceOnExit: true,
      beep: true,
      waitUrl: HOLD_MUSIC_URL,
      waitMethod: 'GET'
    }
    expect(rendered).to dial_conference(dial_options, conference_options)
  end
end
