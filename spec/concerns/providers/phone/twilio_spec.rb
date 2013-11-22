require 'spec_helper'

WebMock.disable_net_connect!

describe Providers::Phone::Twilio do
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(url)
    "CurrentUrl=#{encode(url)}&CurrentMethod=POST"
  end
  let(:call_sid){ '123123' }
  let(:twilio_url) do
    "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls/#{call_sid}"
  end
  let(:url){ "http://test.local/somewhere" }
  let(:valid_response) do
    double('Response', {
      validate_content!: nil
    })
  end

  describe '.redirect(call_sid, url)' do
    before do
      Providers::Phone::Twilio::Response.stub(:new){ valid_response }
    end
    it 'makes redirect request to Twilio' do
      request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                  with(:body => request_body(url))
      Providers::Phone::Twilio.redirect(call_sid, url)
      request.should have_been_made
    end
  end
end