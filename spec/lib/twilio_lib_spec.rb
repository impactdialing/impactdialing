require 'spec_helper'

describe TwilioLib do
  let(:twilio_lib){ TwilioLib.new }
  let(:mailer) do
    double({
      deliver_exception_notification: nil
    })
  end

  describe '#create_http_request(url, params, server)' do
    before do
      UserMailer.stub(:new){ mailer }
    end
    it 'retries 5 times on SocketError' do
      stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@api.twilio.com/nada").to_raise(SocketError).
        with({
          :headers => {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type'=>'application/x-www-form-urlencoded',
            'User-Agent'=>'Ruby'
          }
        }).to_raise(SocketError).times(3).then.to_return({
          :status => 200,
          :body => "fake twilio response",
          :headers => {}
        })
      response = twilio_lib.create_http_request('/nada', {}, 'api.twilio.com')
      response.body.should eq 'fake twilio response'
    end
  end
end