require 'spec_helper'

describe TransferDialer do
  before do
    WebMock.disable_net_connect!
  end
  let(:household) do
    mock_model('Household')
  end
  let(:call_attempt) do
    mock_model('CallAttempt', {
      household: household
    })
  end
  let(:call) do
    mock_model('Call', {
      call_attempt: call_attempt
    })
  end
  let(:voter) do
    mock_model('Voter', {
      household: household
    })
  end
  let(:session_key){ 'caller.session_key-abc123' }
  let(:caller_session) do
    mock_model('CallerSession', {
      campaign_id: 3,
      session_key: session_key
    })
  end
  let(:transfer_attempt) do
    mock_model('TransferAttempt', {
      caller_session: caller_session,
      update_attributes: true,
      session_key: 'transfer-attempt-session-key',
      call_attempt: call_attempt
    })
  end
  let(:transfer_attempts) do
    double('TransferAttemptsCollection', {
      last: transfer_attempt,
      create: transfer_attempt
    })
  end
  let(:transfer) do
    mock_model('Transfer', {
      transfer_attempts: transfer_attempts,
      transfer_type: 'Warm'
    })
  end
  describe '#dial' do
    let(:transfer_dialer) do
      TransferDialer.new(transfer)
    end
    let(:expected_transfer_attempt_attrs) do
      {
        session_key: anything,
        campaign_id: caller_session.campaign_id,
        status: 'Ringing',
        caller_session_id: caller_session.id,
        call_attempt_id: call.call_attempt.id,
        transfer_type: transfer.transfer_type
      }
    end
    let(:success_response) do
      double('Response', {
        error?: false,
        call_sid: '123',
        content: {},
        success?: true
      })
    end
    let(:error_response) do
      double('Response', {
        error?: true,
        content: {},
        success?: false
      })
    end
    before do
      allow(Providers::Phone::Call).to receive(:make){ success_response }
    end

    it 'creates a transfer_attempt' do
      expect(transfer.transfer_attempts).to receive(:create).with(expected_transfer_attempt_attrs){ transfer_attempt }
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'activates the transfer' do
      expect(RedisCallerSession).to receive(:activate_transfer).with(caller_session.session_key, transfer_attempt.session_key)
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'makes the call to connect the transfer' do
      params = Providers::Phone::Call::Params::Transfer.new(transfer, :connect, transfer_attempt)
      expect(Providers::Phone::Call).to receive(:make).with(params.from, params.to, params.url, params.params, Providers::Phone.default_options){ success_response }
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'updates the new transfer_attempt' do
      expect(transfer_attempt).to receive(:update_attributes)
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'returns a hash {type: transfer_type, status: ''}' do
      expect(transfer_dialer.dial(caller_session, call, voter)).to eq({type: transfer.transfer_type, status: nil})
    end

    context 'the transfer succeeds' do
      it 'updates the transfer_attempt sid with the call_sid from the response' do
        expect(transfer_attempt).to receive(:update_attributes).with({sid: success_response.call_sid})
        transfer_dialer.dial(caller_session, call, voter)
      end
    end

    context 'the transfer fails' do
      before do
        allow(Providers::Phone::Call).to receive(:make){ error_response }
      end

      it 'deactivates the transfer' do
        expect(RedisCallerSession).not_to receive(:activate_transfer)
        transfer_dialer.dial(caller_session, call, voter)
      end

      it 'updates the transfer_attempt status with "Call failed"' do
        expect(transfer_attempt).to receive(:update_attributes).with({status: 'Call failed'})
        transfer_dialer.dial(caller_session, call, voter)
      end
    end
  end
end