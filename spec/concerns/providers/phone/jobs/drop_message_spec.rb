require 'spec_helper'

describe Providers::Phone::Jobs::DropMessage do
  let(:recording){ create(:recording) }
  let(:campaign){ create(:power, {recording: recording}) }
  let(:caller){ create(:caller, {campaign: campaign}) }
  let(:caller_session){ create(:webui_caller_session, {caller: caller}) }
  let(:voter){ create(:voter, {campaign: campaign}) }
  let(:call_attempt){ create(:call_attempt, {voter: voter, campaign: campaign, caller_session: caller_session}) }
  let(:call){ create(:call, {call_attempt: call_attempt}) }
  let(:response){ double('Response', {error?: false}) }

  subject{ Providers::Phone::Jobs::DropMessage.new }

  before do
    allow(Providers::Phone::Call).to receive(:play_message_for){ response }
    allow(Providers::Phone::Call).to receive(:redirect_for){ response }
  end

  it 'tells Providers::Phone::Call play_message_for call' do
    expect(Providers::Phone::Call).to receive(:play_message_for).with(call){ response }
    subject.perform(call.id)
  end

  context 'when message plays successfully' do
    it 'caller is redirect automatically via action attr on Dial verb from previous TwiML' do
    end
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
      subject.perform(call.id)
    end
    it 'redirects caller voice to play_message_error' do
      expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, :play_message_error)
      subject.perform(call.id)
    end
  end
end