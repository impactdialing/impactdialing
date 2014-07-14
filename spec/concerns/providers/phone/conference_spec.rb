require 'spec_helper'

describe Providers::Phone::Conference do

  let(:conference_name) do
    'Waiting room'
  end

  before do
    WebMock.disable_net_connect!
    stub_twilio_conference_by_name_request
  end

  describe '.sid_for(name, opts)' do
    it 'returns the sid for named conference' do
      expected = 'CFww834eJSKDJFjs328JF92JSDFwe'
      actual = Providers::Phone::Conference.sid_for(conference_name)
      expect(actual).to eq expected
    end
  end

  describe '.toggle_mute_for(name, call_sid, opts={})' do
    let(:caller){ create(:caller) }
    let(:caller_session) do
      create(:webui_caller_session, {
        caller: caller, session_key: conference_name
      })
    end
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }
    let(:call_sid){ caller_session.sid }

    before do
      stub_twilio_conference_by_name_request
      stub_twilio_mute_participant_request
      stub_twilio_unmute_participant_request
    end
    it 'requests an update of the named conference call Mute property' do
      Providers::Phone::Conference.toggle_mute_for(conference_name, call_sid, {mute: true})
      expect(@mute_participant_request).to have_been_made
      expect(@unmute_participant_request).not_to have_been_made
    end
    it 'returns the response of the request' do
      toggle_response = Providers::Phone::Conference.toggle_mute_for(conference_name, call_sid, {mute: true})
      expect(toggle_response).to be_instance_of Providers::Phone::Twilio::Response
    end
    context 'opts[:mute] is false' do
      it 'updates the Mute property to false' do
        Providers::Phone::Conference.toggle_mute_for(conference_name, call_sid, {mute: false})
        expect(@unmute_participant_request).to have_been_made
        expect(@mute_participant_request).not_to have_been_made
      end
    end
  end
end
