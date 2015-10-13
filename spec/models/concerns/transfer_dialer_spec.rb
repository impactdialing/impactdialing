require 'rails_helper'

describe TransferDialer do
  include Rails.application.routes.url_helpers

  before do
    WebMock.disable_net_connect!
  end
  let(:session_key){ 'caller.session_key-abc123' }
  let(:caller_session) do
    create(:caller_session, {
      campaign_id: 3,
      session_key: session_key
    })
  end
  let(:transfer_attempt) do
    create(:transfer_attempt, {
      caller_session: caller_session,
      session_key: 'transfer-attempt-session-key'
    })
  end
  let(:transfer) do
    create(:transfer, {
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
    let(:dialed_call_storage) do
      instance_double('CallFlow::Call::Storage', {
        :[]= => nil
      })
    end
    let(:dialed_call) do
      instance_double('CallFlow::Call::Dialed', {
        storage: dialed_call_storage,
        transfer_attempted: nil
      })
    end

    before do
      allow(dialed_call_storage).to receive(:[]).with(:phone){ twilio_valid_to }
      allow(caller_session).to receive(:dialed_call){ dialed_call }
      allow(Providers::Phone::Call).to receive(:make){ success_response }
    end

    it 'creates a transfer_attempt' do
      expect(transfer.transfer_attempts).to receive(:create).with(expected_transfer_attempt_attrs){ transfer_attempt }
      transfer_dialer.dial(caller_session)
    end

    it 'makes the call to connect the transfer' do
      expect(Providers::Phone::Call).to(
        receive(:make).with(
          twilio_valid_to,
          transfer.phone_number,
          connect_transfer_url(transfer_attempt.id + 1, host: 'test.com'),
          {
            "StatusCallback" => end_transfer_url(transfer_attempt.id + 1, host: 'test.com'),
            "Timeout" => ENV['DIAL_TRANSFER_TIMEOUT'] || '15'
          },
          {
            retry_up_to: ENV['TWILIO_RETRIES']
          })
      ){ success_response }
      transfer_dialer.dial(caller_session)
    end

    it 'returns a hash {type: transfer_type, status: ''}' do
      expect(transfer_dialer.dial(caller_session)).to eq({type: transfer.transfer_type, status: 'Ringing'})
    end

    context 'the transfer succeeds' do
      it 'updates the transfer_attempt sid with the call_sid from the response' do
        transfer_dialer.dial(caller_session)
        expect(transfer.transfer_attempts.last.sid).to eq success_response.call_sid
      end
    end

    context 'the transfer fails' do
      before do
        allow(Providers::Phone::Call).to receive(:make){ error_response }
      end

      it 'updates the transfer_attempt status with "Call failed"' do
        transfer_dialer.dial(caller_session)
        expect(transfer.transfer_attempts.last.status).to eq 'Call failed'
      end
    end
  end
end
