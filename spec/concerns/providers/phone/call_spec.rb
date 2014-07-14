require 'spec_helper'

describe Providers::Phone::Call do

  let(:service_obj){ double }
  let(:call_sid){ '123123' }
  let(:url){ 'http://test.local/somewhere' }
  let(:valid_response) do
    double('Response', {
      validate_content!: nil
    })
  end

  before do
    WebMock.disable_net_connect!
  end

  describe '.redirect(call_sid, url)' do
    it 'forwards redirect message to .service obj' do
      allow(Providers::Phone::Call).to receive(:service){ service_obj }
      expect(service_obj).to receive(:redirect).with(call_sid, url)
      Providers::Phone::Call.redirect(call_sid, url)
    end

    it 'retries specified times on SocketError' do
      request = stub_request(:post, twilio_call_url(call_sid)).
                  with(:body => request_body(url)).
                  to_raise(SocketError).times(4).then.
                  to_return({
                    :status => 200,
                    :body => "",
                    :headers => {}
                  })
      allow(Providers::Phone::Twilio::Response).to receive(:new){ valid_response }
      Providers::Phone::Call.redirect(call_sid, url, {retry_up_to: 5})
      expect(request).to have_been_made.times(5)
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
      allow(Providers::Phone::Call::Params).to receive(:for){ call_params }
      allow(Providers::Phone::Call).to receive(:redirect)
    end

    it 'asks Call::Params for args to redirect' do
      expect(Providers::Phone::Call::Params).to receive(:for).with(ar_model, type){ call_params }
      Providers::Phone::Call.redirect_for(ar_model, type)
    end

    it 'sends itself .redirect(call_params.call_sid, call_params.url, {:retry_up_to => Integer})' do
      expect(Providers::Phone::Call).to receive(:redirect).with(call_params.call_sid, call_params.url, {retry_up_to: anything})
      Providers::Phone::Call.redirect_for(ar_model, type)
    end
  end
end
