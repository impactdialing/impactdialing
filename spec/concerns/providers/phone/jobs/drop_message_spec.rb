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
    Providers::Phone::Call.stub(:play_message_for){ response }
    Providers::Phone::Call.stub(:redirect_for){ response }
  end

  it 'tells Providers::Phone::Call play_message_for call' do
    Providers::Phone::Call.should_receive(:play_message_for).with(call){ response }
    subject.perform(call.id)
  end

  context 'when message plays successfully' do
    it 'caller is redirect automatically via action attr on Dial verb from previous TwiML' do
    end
  end

  context 'when message play fails' do
    let(:response2){ double('ResponseDeux') }
    before do
      caller_session.stub(:publish_message_drop_error)
      response.stub(:error?){ true }
      response.stub(:response){ response2 }
      subject.stub(:request_message_drop){ response }
    end
    it 'notifies caller client of the error' do
      subject.should_receive(:notify_client_of_error)
      # odd error re: backtrace arguments when attempting to set expectation
      # on caller_session
      subject.perform(call.id)
    end
    it 'redirects caller voice to play_message_error' do
      Providers::Phone::Call.should_receive(:redirect_for).with(caller_session, :play_message_error)
      subject.perform(call.id)
    end
  end
end