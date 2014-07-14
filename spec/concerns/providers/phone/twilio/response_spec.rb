require 'spec_helper'

describe Providers::Phone::Twilio::Response do
  def httparty_response(code, body)
    double('HTTPartyInstance', {
      code: code,
      parsed_response: body,
      :[] => {}
    })
  end
  let(:valid_content) do
    {
      'TwilioResponse' => {
        'Status' => '200',
        'Call' => {
          'Sid' => '123'
        }
      }
    }
  end
  let(:valid_content_with_error) do
    {
      'TwilioResponse' => {
        'RestException' => 'something went wrong'
      }
    }
  end
  let(:invalid_content) do
    {
      'UnknownNode' => {}
    }
  end
  let(:empty_content) do
    ''
  end
  let(:success_response) do
    Providers::Phone::Twilio::Response.new(httparty_response('200', valid_content))
  end
  let(:bodyless_response) do
    Providers::Phone::Twilio::Response.new(httparty_response('204', empty_content))
  end
  let(:error_response) do
    Providers::Phone::Twilio::Response.new(httparty_response('400', valid_content_with_error))
  end
  describe 'new instance' do
    it 'sets @content to the value of TwilioResponse node' do
      expect(success_response.content).to eq valid_content['TwilioResponse']
    end

    it 'sets @content to the value of response.parsed_response w/out TwilioResponse node' do
      expect(bodyless_response.content).to be_nil
    end
  end

  describe 'testing response success' do
    describe '#success?' do
      it 'returns true when status is 2xx' do
        expect(bodyless_response.success?).to be_truthy
      end

      it 'returns false when RestException node is found' do
        expect(error_response.success?).to be_falsey
      end
    end

    describe '#error?' do
      it 'returns true when RestException node is found' do
        expect(error_response.error?).to be_truthy
      end

      it 'returns false when RestException node is not found' do
        expect(success_response.error?).to be_falsey
      end
    end
  end

  describe '#call_sid' do
    it 'returns the value of content["Call"]["Sid"] node' do
      expect(success_response.call_sid).to eq valid_content['TwilioResponse']['Call']['Sid']
    end
  end

  describe '#status' do
    it 'returns httparty_response.code.to_i' do
      expect(success_response.status).to eq valid_content['TwilioResponse']['Status'].to_i
    end
  end
end
