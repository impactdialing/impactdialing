require 'rails_helper'

describe Providers::Phone::Jobs::DropMessage do
  let(:recording){ create(:recording) }
  let(:campaign){ create(:power, {recording: recording}) }
  let(:caller){ create(:caller, {campaign: campaign}) }
  let(:caller_session){ create(:webui_caller_session, {caller: caller, sid: 'CA-321'}) }
  let(:response){ double('Response', {error?: false}) }
  let(:call_sid){ 'CA-123' }

  subject{ Providers::Phone::Jobs::DropMessage.new }

  before do
    allow(Providers::Phone::Call).to receive(:play_message_for){ response }
    allow(Providers::Phone::Call).to receive(:redirect_for){ response }
  end

  it 'tells Providers::Phone::Call play_message_for call' do
    expect(Providers::Phone::Call).to receive(:play_message_for).with(call_sid){ response }
    subject.perform(caller_session.sid, call_sid)
  end

  context 'when message play fails' do
    let(:response2){ double('ResponseDeux') }
    before do
      allow(caller_session).to receive(:publish_message_drop_error)
      allow(response).to receive(:error?){ true }
      allow(response).to receive(:response){ response2 }
      allow(subject).to receive(:request_message_drop){ response }
    end
    it 'notifies caller client of the error' do
      expect(subject).to receive(:notify_client_of_error)
      # odd error re: backtrace arguments when attempting to set expectation
      # on caller_session
      subject.perform(caller_session.sid, call_sid)
    end
    it 'redirects caller voice to play_message_error' do
      expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, :play_message_error)
      subject.perform(caller_session.sid, call_sid)
    end
  end
end
