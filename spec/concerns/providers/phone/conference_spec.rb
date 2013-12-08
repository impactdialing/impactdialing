require 'spec_helper'

describe Providers::Phone::Conference do

  let(:conference_name) do
    'Waiting room'
  end

  before do
    WebMock.disable_net_connect!
    stub_twilio_conference_by_name_request
  end

  describe '.sid_for(name, opts)' do
    it 'returns the sid for named conference' do
      expected = 'CFww834eJSKDJFjs328JF92JSDFwe'
      actual = Providers::Phone::Conference.sid_for(conference_name)
      actual.should eq expected
    end
  end
end
