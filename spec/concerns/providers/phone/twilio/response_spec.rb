require 'spec_helper'

describe Providers::Phone::Twilio::Response do
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
        'Status' => '200',
        'RestException' => 'something went wrong'
      }
    }
  end
  let(:invalid_content) do
    {
      'UnknownNode' => {}
    }
  end
  let(:bodyless_content) do
    double('HTTPARTY RESPONSE', {
      code: 204,
      body: '',
      headers: {},
      :[] => nil,
      :size => 0
    })
  end
  let(:success_response) do
    Providers::Phone::Twilio::Response.new(valid_content)
  end
  let(:bodyless_response) do
    Providers::Phone::Twilio::Response.new(bodyless_content)
  end
  let(:error_response) do
    Providers::Phone::Twilio::Response.new(valid_content_with_error)
  end
  describe 'new instance' do
    it 'sets @content to the value of TwilioResponse node' do
      success_response.content.should eq valid_content['TwilioResponse']
    end

    it 'raises InvalidContent when missing TwilioResponse node' do
      lambda{
        Providers::Phone::Twilio::Response.new(invalid_content)
      }.should raise_error(Providers::Phone::Twilio::Response::InvalidContent)
    end
  end

  describe 'testing response success' do
    describe '#success?' do
      it 'returns true when no RestException node is not found' do
        success_response.success?.should be_true
      end

      it 'returns true when status is 2xx' do
        bodyless_response.success?.should be_true
      end

      it 'returns false when RestException node is found' do
        error_response.success?.should be_false
      end
    end

    describe '#error?' do
      it 'returns true when RestException node is found' do
        error_response.error?.should be_true
      end

      it 'returns false when RestException node is not found' do
        success_response.error?.should be_false
      end
    end
  end

  describe '#call_sid' do
    it 'returns the value of content["Call"]["Sid"] node' do
      success_response.call_sid.should eq valid_content['TwilioResponse']['Call']['Sid']
    end
  end

  describe '#status' do
    it 'returns the value of content["Status"]' do
      success_response.status.should eq valid_content['TwilioResponse']['Status'].to_i
    end

    it 'returns the value of content.code when content["Status"] is nil' do
      bodyless_response.status.should eq bodyless_content.code.to_i
    end
  end
end
