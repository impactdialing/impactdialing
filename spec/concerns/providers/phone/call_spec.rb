require 'spec_helper'

WebMock.disable_net_connect!

describe Providers::Phone::Call do
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(url)
    "CurrentUrl=#{encode(url)}&CurrentMethod=POST"
  end
  let(:caller_session) do
    double('CallerSession', {
      id: 34,
      data_centre: nil
    })
  end
  let(:call_sid){ '123123' }
  let(:twilio_url) do
    "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls/#{call_sid}"
  end
  let(:url){ "http://test.local/somewhere" }

  describe '.redirect(call_sid, url)' do
    it 'forwards the method and args to CURRENT_PROVIDER' do
      request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                  with(:body => request_body(url))
      Providers::Phone::Call.redirect(call_sid, url)
      request.should have_been_made
    end

    it 'retries NUMBER_OF_RETRIES times on SocketError' do
      request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                  with(:body => request_body(url)).
                  to_raise(SocketError).times(4).then.
                  to_return({
                    :status => 200,
                    :body => "",
                    :headers => {}
                  })
      Providers::Phone::Call.redirect(call_sid, url)
      request.should have_been_made.times(5)
    end
  end
end