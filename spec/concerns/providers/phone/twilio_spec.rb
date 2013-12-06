require 'spec_helper'

describe Providers::Phone::Twilio do
  include TwilioRequests
  include TwilioResponses

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
      @request = stub_request(:post, twilio_call_url(call_sid)).
        with(:body => request_body(url)).
        to_return({
          :status => 200,
          :body => updated_call_response,
          :headers => {
            'Content-Type' => 'text/xml'
          }
        })
      @response = Providers::Phone::Twilio.redirect(call_sid, url)
    end
    it 'makes redirect request to Twilio' do
      @request.should have_been_made
    end

    it 'returns a Response instance' do
      @response.should be_instance_of Providers::Phone::Twilio::Response
    end
  end

  describe '.make(from, to, url, params)' do
    let(:from){ '11234567890' }
    let(:to){ '14325551234' }

    before do
      @request = stub_request(:post, twilio_calls_url).
        to_return({
          :status => 200,
          :body => new_call_response,
          :headers => {
            'Content-Type' => 'text/xml'
          }
        })
      @response = Providers::Phone::Twilio.make(from, to, twilio_calls_url, {})
    end
    it 'starts a new call' do
      @request.should have_been_made
    end

    it 'returns a Response instance' do
      @response.should be_instance_of Providers::Phone::Twilio::Response
    end
  end

  describe '.conference_list(search_options)' do
    before do
      @request = stub_request(:get, twilio_conferences_url).
        to_return({
          :status => 200,
          :body => conference_list_response,
          :headers => {
            'Content-Type' => 'text/xml'
          }
        })
      @response = Providers::Phone::Twilio.conference_list
    end

    it 'requests a list of conferences' do
      @request.should have_been_made
    end

    it 'returns a Response instance' do
      @response.should be_instance_of Providers::Phone::Twilio::Response
    end

    context 'search_options hash is not empty' do
      let(:name){ 'Conference Name' }

      before do
        @request = stub_request(:get, twilio_conference_by_name_url(name)).
          to_return({
            :status => 200,
            :body => conference_by_name_response,
            :headers => {
              'Content-Type' => 'text/xml'
            }
          })
        @response = Providers::Phone::Twilio.conference_list({
          'FriendlyName' => name
        })
      end

      it 'requests conferences that match search_options' do
        @request.should have_been_made
      end
    end
  end

  describe '.kick(conference_sid, call_sid)' do
    let(:conference_sid){ 'confsid-abc-123' }
    let(:call_sid){ 'callsid-123-abc' }

    before do
      @request = stub_request(:delete, twilio_conference_kick_participant_url(conference_sid, call_sid)).
        to_return({
          :status => 204
        })
      @response = Providers::Phone::Twilio.kick(conference_sid, call_sid)
    end

    it 'removes call w/ call_sid from conference w/ conference_sid' do
      @request.should have_been_made
    end

    it 'returns Response instance' do
      @response.should be_instance_of Providers::Phone::Twilio::Response
    end
  end
end
