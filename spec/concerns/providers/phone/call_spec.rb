require 'spec_helper'

describe Providers::Phone::Call do
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(url)
    "CurrentUrl=#{encode(url)}&CurrentMethod=POST"
  end

  let(:service_obj){ double }
  let(:call_sid){ '123123' }
  let(:url){ 'http://test.local/somewhere' }
  let(:twilio_url) do
    "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls/#{call_sid}"
  end

  before do
    WebMock.disable_net_connect!
  end

  describe '.redirect(call_sid, url)' do
    it 'forwards redirect message to .service obj' do
      Providers::Phone::Call.stub(:service){ service_obj }
      service_obj.should_receive(:redirect).with(call_sid, url)
      Providers::Phone::Call.redirect(call_sid, url)
    end

    it 'retries specified times on SocketError' do
      request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                  with(:body => request_body(url)).
                  to_raise(SocketError).times(4).then.
                  to_return({
                    :status => 200,
                    :body => "",
                    :headers => {}
                  })
      Providers::Phone::Call.redirect(call_sid, url, {retry_up_to: 5})
      request.should have_been_made.times(5)
    end
  end

  describe '.redirect_for(obj, type=:default)' do
    let(:call_params) do
      double('CallParams', {
        call_sid: call_sid,
        url: url
      })
    end
    let(:ar_model) do
      double('ARModel')
    end
    let(:type){ 'ar_url_name' }
    before do
      Providers::Phone::Call::Params.stub(:for){ call_params }
      Providers::Phone::Call.stub(:redirect)
    end

    it 'asks Call::Params for args to redirect' do
      Providers::Phone::Call::Params.should_receive(:for).with(ar_model, type){ call_params }
      Providers::Phone::Call.redirect_for(ar_model, type)
    end

    it 'sends itself .redirect(call_params.call_sid, call_params.url, {:retry_up_to => Integer})' do
      Providers::Phone::Call.should_receive(:redirect).with(call_params.call_sid, call_params.url, {retry_up_to: anything})
      Providers::Phone::Call.redirect_for(ar_model, type)
    end
  end
end
