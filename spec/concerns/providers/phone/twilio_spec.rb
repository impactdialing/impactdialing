require 'spec_helper'

describe Providers::Phone::Twilio do

  before do
    WebMock.disable_net_connect!
  end

  let(:call_sid){ '123123' }
  let(:url){ "http://test.local/somewhere" }
  let(:valid_response) do
    double('Response', {
      validate_content!: nil
    })
  end

  describe '.redirect(call_sid, url)' do
    before do
      stub_twilio_redirect_request(url)
      @response = Providers::Phone::Twilio.redirect(call_sid, url)
    end
    it 'makes redirect request to Twilio' do
      expect(@redirect_request).to have_been_made
    end

    it 'returns a Response instance' do
      expect(@response).to be_instance_of Providers::Phone::Twilio::Response
    end
  end

  describe '.make(from, to, url, params)' do
    let(:from){ '11234567890' }
    let(:to){ '14325551234' }

    before do
      stub_twilio_new_call_request
      @response = Providers::Phone::Twilio.make(from, to, twilio_calls_url, {})
    end
    it 'starts a new call' do
      expect(@new_call_request).to have_been_made
    end

    it 'returns a Response instance' do
      expect(@response).to be_instance_of Providers::Phone::Twilio::Response
    end
  end

  describe '.conference_list(search_options)' do
    before do
      stub_twilio_conference_list_request
      @response = Providers::Phone::Twilio.conference_list
    end

    it 'requests a list of conferences' do
      expect(@conference_list_request).to have_been_made
    end

    it 'returns a Response instance' do
      expect(@response).to be_instance_of Providers::Phone::Twilio::Response
    end

    context 'search_options hash is not empty' do
      let(:conference_name){ 'Conference Name' }

      before do
        stub_twilio_conference_by_name_request
        @response = Providers::Phone::Twilio.conference_list({
          'FriendlyName' => conference_name
        })
      end

      it 'requests conferences that match search_options' do
        expect(@conf_by_name_request).to have_been_made
      end
    end
  end

  describe '.kick(conference_sid, call_sid)' do
    let(:conference_sid){ 'confsid-abc-123' }
    let(:call_sid){ 'callsid-123-abc' }

    before do
      stub_twilio_kick_participant_request
      @response = Providers::Phone::Twilio.kick(conference_sid, call_sid)
    end

    it 'removes call w/ call_sid from conference w/ conference_sid' do
      expect(@kick_request).to have_been_made
    end

    it 'returns Response instance' do
      expect(@response).to be_instance_of Providers::Phone::Twilio::Response
    end
  end

  describe 'muting and unmuting conference participants' do
    let(:call_sid){ 'callsid-123-abc' }
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }
    let(:conference_name){ 'Waiting room' }

    before do
      stub_twilio_conference_by_name_request
    end
    describe '.mute_participant(conference_sid, call_sid)' do
      before do
        stub_twilio_mute_participant_request
        @response = Providers::Phone::Twilio.mute_participant(conference_sid, call_sid)
      end

      it 'updates Mute property to true for identified call on named conference' do
        expect(@mute_participant_request).to have_been_made
      end
      it 'returns Response instance' do
        expect(@response).to be_instance_of Providers::Phone::Twilio::Response
      end
    end

    describe '.unmute_participant(conference_sid, call_sid)' do
      before do
        stub_twilio_unmute_participant_request
        @response = Providers::Phone::Twilio.unmute_participant(conference_sid, call_sid)
      end

      it 'updates Mute property to false for identified call on named conference' do
        expect(@unmute_participant_request).to have_been_made
      end
      it 'returns Response instance' do
        expect(@response).to be_instance_of Providers::Phone::Twilio::Response
      end
    end
  end
end
