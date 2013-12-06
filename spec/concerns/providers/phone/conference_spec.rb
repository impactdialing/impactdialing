require 'spec_helper'

describe Providers::Phone::Conference do
  include TwilioRequests
  include TwilioResponses

  let(:friendly_name) do
    'Waiting room'
  end

  before do
    WebMock.disable_net_connect!
    stub_request(:get, twilio_conference_by_name_url(friendly_name)).
    to_return({
      :status => 200,
      :body => conference_by_name_response,
      :headers => {
        'Content-Type' => 'text/xml'
      }
    })
  end

  describe '.sid_for(name, opts)' do
    it 'returns the sid for named conference' do
      expected = 'CFww834eJSKDJFjs328JF92JSDFwe'
      actual = Providers::Phone::Conference.sid_for(friendly_name)
      actual.should eq expected
    end
  end
end
