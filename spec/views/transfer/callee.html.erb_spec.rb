require 'rails_helper'

describe 'transfer/callee.html.erb' do
  let(:caller_record){ create(:caller) }
  let(:caller_session){ create(:caller_session, caller: caller_record) }
  let(:transfer_attempt){ create(:transfer_attempt, :with_session_key) }
  let(:dial_options) do
    {
      hangupOnStar: true
    }
  end
  let(:conference_options) do
    {
      name: transfer_attempt.session_key,
      startConferenceOnEnter: true,
      endConferenceOnExit: false,
      beep: false,
      waitUrl: HOLD_MUSIC_URL,
      waitMethod: 'GET'
    }
  end

  it 'dials the caller into the conference' do
    assign(:caller, caller_record)
    assign(:caller_session, caller_session)
    assign(:session_key, transfer_attempt.session_key)
    render template: 'transfer/callee.html.erb'

    expect(rendered).to dial_conference(dial_options, conference_options)
  end
end
