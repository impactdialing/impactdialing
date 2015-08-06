require 'rails_helper'

describe Providers::Phone::Call::Params::Call do
  include Rails.application.routes.url_helpers

  let(:call_sid){ 'CA-123' }
  let(:param_class) do
    Providers::Phone::Call::Params::Call
  end
  let(:url_opts) do
    Providers::Phone::Call::Params.default_url_options
  end

  describe '#url' do
    it 'returns twiml_lead_play_message_url(url_options)' do
      params = param_class.new(call_sid)
      expect(params.url).to eq twiml_lead_play_message_url(url_opts)
    end
  end
end
