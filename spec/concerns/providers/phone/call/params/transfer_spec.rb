require 'spec_helper'

describe Providers::Phone::Call::Params::Transfer do
  include Rails.application.routes.url_helpers

  let(:voter) do
    mock_model('Voter')
  end
  let(:caller_session) do
    mock_model('CallerSession', {
      voter_in_progress: voter
    })
  end
  let(:transfer_attempt) do
    mock_model('TransferAttempt',{
      caller_session: caller_session
    })
  end
  let(:transfer) do
    mock_model('Transfer', {
      transfer_attempts: [transfer_attempt]
    })
  end
  let(:param_class) do
    Providers::Phone::Call::Params::Transfer
  end
  let(:url_opts) do
    Providers::Phone::Call::Params.default_url_options
  end

  describe 'returning urls on type requested' do
    it 'returns end_transfer_url when type == :end' do
      params = param_class.new(transfer, :end)
      params.url.should eq end_transfer_url(transfer_attempt, url_opts)
    end

    it 'returns connect_transfer_url when type == :connect' do
      params = param_class.new(transfer, :connect)
      params.url.should eq connect_transfer_url(transfer_attempt, url_opts)
    end
  end
end