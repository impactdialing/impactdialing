require 'spec_helper'

describe Providers::Phone::Call::Params::Call do
  include Rails.application.routes.url_helpers

  let(:call) do
    mock_model('Call')
  end
  let(:param_class) do
    Providers::Phone::Call::Params::Call
  end
  let(:url_opts) do
    Providers::Phone::Call::Params.default_url_options
  end

  describe '#url' do
    it 'returns play_message_call_url(call, url_options' do
      params = param_class.new(call)
      expect(params.url).to eq play_message_call_url(call, url_opts)
    end
  end
end