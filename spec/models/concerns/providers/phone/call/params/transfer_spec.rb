require 'rails_helper'

describe Providers::Phone::Call::Params::Transfer do
  include Rails.application.routes.url_helpers

  let(:voter) do
    create(:voter)
  end
  let(:caller_session) do
    create(:caller_session)
  end
  let(:call_sid) do
    'lead-call-sid-123'
  end
  let(:transfer) do
    create(:transfer)
  end
  let(:transfer_attempt) do
    create(:transfer_attempt,{
      caller_session: caller_session,
      transfer: transfer
    })
  end
  let(:lead_call_storage) do
    instance_double('CallFlow::Call::Storage')
  end
  let(:lead_call) do
    instance_double('CallFlow::Call::Dialed', {
      sid: call_sid,
      storage: lead_call_storage
    })
  end
  let(:param_class) do
    Providers::Phone::Call::Params::Transfer
  end
  let(:url_opts) do
    Providers::Phone::Call::Params.default_url_options
  end

  before do
    allow(lead_call_storage).to receive(:[]).with(:phone){ twilio_valid_to }
  end

  describe 'returning urls on type requested' do
    it 'returns end_transfer_url when type == :end' do
      params = param_class.new(transfer, :end, transfer_attempt, lead_call)
      expect(params.url).to eq end_transfer_url(transfer_attempt, url_opts)
    end

    it 'returns connect_transfer_url when type == :connect' do
      params = param_class.new(transfer, :connect, transfer_attempt, lead_call)
      expect(params.url).to eq connect_transfer_url(transfer_attempt, url_opts)
    end

    it 'returns callee_transfer_index_url when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt, lead_call)
      expect(params.url).to eq callee_transfer_index_url(url_opts)
    end

    it 'returns caller_transfer_index_url when type == :caller' do
      params = param_class.new(transfer, :caller, transfer_attempt, lead_call)
      opts = url_opts.merge({caller_session: transfer_attempt.caller_session.id})
      expect(params.url).to eq caller_transfer_index_url(opts)
    end
  end

  describe 'returning call_sid on type requested' do
    it 'returns call_attempt.sid when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt, lead_call)
      expect(params.call_sid).to eq call_sid
    end

    it 'returns caller_transfer_index_url when type == :caller' do
      params = param_class.new(transfer, :caller, transfer_attempt, lead_call)
      expect(params.call_sid).to eq caller_session.sid
    end
  end

  describe 'returning url_options on type requested' do
    it 'includes :session_key when type == :callee' do
      params = param_class.new(transfer, :callee, transfer_attempt, lead_call)
      expect(params.callee_url_options[:session_key]).to eq transfer_attempt.session_key
    end

    it 'includes :session_key and :caller_session' do
      params = param_class.new(transfer, :caller, transfer_attempt, lead_call)
      expect(params.caller_url_options[:session_key]).to eq transfer_attempt.session_key
      expect(params.caller_url_options[:caller_session]).to eq caller_session.id
    end
  end
end
