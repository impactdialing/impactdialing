require 'rails_helper'

describe 'transfer/connect.html.erb' do
  let(:caller_record){ create(:caller) }
  let(:caller_session){ create(:caller_session, caller: caller_record) }
  let(:transfer_attempt){ create(:transfer_attempt, :with_session_key) }
  let(:dial_options) do
    {
      hangupOnStar: true,
      action: disconnect_transfer_url(transfer_attempt, {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: 'http://'
      })
    }
  end
  let(:conference_options) do
    {
      name: transfer_attempt.session_key,
      endConferenceOnExit: false,
      beep: false,
      waitUrl: HOLD_MUSIC_URL,
      waitMethod: 'GET'
    }
  end

  it 'dials the caller into the conference' do
    assign(:transfer_attempt, transfer_attempt)
    render template: 'transfer/connect.html.erb'

    expect(rendered).to dial_conference(dial_options, conference_options)
  end
end
