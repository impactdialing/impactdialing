require 'rails_helper'

describe CallFlow::Web::Event do
  describe '.publish' do
    subject{ CallFlow::Web::Event }
    it "submits a request to Pusher API" do
      response = nil
      VCR.use_cassette('Pusher success request', {
        :match_requests_on => [
          :method,
          :host,
          VCR.request_matchers.uri_without_param(:auth_timestamp, :auth_signature)
        ]
      }) do
        response = subject.publish("channel_name", "event_name", { payload: "data" })
      end
      expect(response).to be_kind_of Hash
    end
  end
end
