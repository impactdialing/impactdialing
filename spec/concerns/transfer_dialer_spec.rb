require 'spec_helper'

describe TransferDialer do
  before do
    WebMock.disable_net_connect!
  end

  let(:call_attempt) do
    mock_model('CallAttempt')
  end
  let(:call) do
    mock_model('Call', {
      call_attempt: call_attempt
    })
  end
  let(:voter) do
    mock_model('Voter')
  end
  let(:caller_session) do
    mock_model('CallerSession', {
      campaign_id: 3,
      voter_in_progress: voter
    })
  end
  let(:transfer_attempt) do
    mock_model('TransferAttempt', {
      caller_session: caller_session,
      update_attributes: true
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
        call_sid: '123'
      })
    end
    let(:error_response) do
      double('Response', {
        error?: true
      })
    end
    before do
      Providers::Phone::Call.stub(:make){ success_response }
    end

    it 'creates a transfer_attempt' do
      transfer.transfer_attempts.should_receive(:create).with(expected_transfer_attempt_attrs){ transfer_attempt }
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'makes the call to connect the transfer' do
      Providers::Phone::Call.should_receive(:make_for).with(transfer, :connect){ success_response }
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'updates the new transfer_attempt' do
      transfer_attempt.should_receive(:update_attributes)
      transfer_dialer.dial(caller_session, call, voter)
    end

    it 'returns a hash {type: transfer_type}' do
      transfer_dialer.dial(caller_session, call, voter).should eq({type: transfer.transfer_type})
    end

    context 'the transfer succeeds' do
      it 'updates the transfer_attempt sid with the call_sid from the response' do
        transfer_attempt.should_receive(:update_attributes).with({sid: success_response.call_sid})
        transfer_dialer.dial(caller_session, call, voter)
      end
    end

    context 'the transfer fails' do
      it 'updates the transfer_attempt status with "Call failed"' do
        Providers::Phone::Call.stub(:make){ error_response }
        transfer_attempt.should_receive(:update_attributes).with({status: 'Call failed'})
        transfer_dialer.dial(caller_session, call, voter)
      end
    end
  end
end