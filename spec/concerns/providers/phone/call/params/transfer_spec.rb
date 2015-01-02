require 'spec_helper'

describe Providers::Phone::Call::Params::Transfer do
  include Rails.application.routes.url_helpers

  let(:voter) do
    mock_model('Voter')
  end
  let(:caller_session) do
    mock_model('CallerSession')
  end
  let(:call_attempt) do
    mock_model('CallAttempt', {
      sid: 'call-attempt-sid-123'
    })
  end
  let(:transfer_attempt) do
    mock_model('TransferAttempt',{
      caller_session: caller_session,
      call_attempt: call_attempt
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
      params = param_class.new(transfer, :end, transfer_attempt)
      expect(params.url).to eq end_transfer_url(transfer_attempt, url_opts)
    end

    it 'returns connect_transfer_url when type == :connect' do
      params = param_class.new(transfer, :connect, transfer_attempt)
      expect(params.url).to eq connect_transfer_url(transfer_attempt, url_opts)
    end

    it 'returns callee_transfer_index_url when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt)
      expect(params.url).to eq callee_transfer_index_url(url_opts)
    end

    it 'returns caller_transfer_index_url when type == :caller' do
      params = param_class.new(transfer, :caller, transfer_attempt)
      opts = url_opts.merge({caller_session: transfer_attempt.caller_session.id})
      expect(params.url).to eq caller_transfer_index_url(opts)
    end
  end

  describe 'returning call_sid on type requested' do
    it 'returns call_attempt.sid when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt)
      expect(params.call_sid).to eq call_attempt.sid
    end

    it 'returns caller_transfer_index_url when type == :caller' do
      params = param_class.new(transfer, :caller, transfer_attempt)
      expect(params.call_sid).to eq caller_session.sid
    end
  end

  describe 'returning url_options on type requested' do
    it 'includes :session_key when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt)
      expect(params.callee_url_options[:session_key]).to eq transfer_attempt.session_key
    end

    it 'includes :session_key and :caller_session' do
      params = param_class.new(transfer, :caller, transfer_attempt)
      expect(params.caller_url_options[:session_key]).to eq transfer_attempt.session_key
      expect(params.caller_url_options[:caller_session]).to eq caller_session.id
    end
  end
end
