require 'rails_helper'

describe TransferDialer do
  include Rails.application.routes.url_helpers

  before do
    webmock_disable_net!
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
      transfer_type: 'Warm',
      phone_number: twilio_valid_to
    })
  end
  describe '#dial' do
    let(:transfer_dialer) do
      TransferDialer.new(transfer)
    end
    let(:expected_transfer_attempt_attrs) do
      {
        campaign_id: caller_session.campaign_id,
        status: 'Ringing',
        caller_session_id: caller_session.id,
        transfer_type: transfer.transfer_type
      }
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
    end

    it 'creates a transfer_attempt' do
      VCR.use_cassette('TransferDialerSuccessfulDial') do
        transfer_dialer.dial(caller_session)
      end

      transfer_attempt = TransferAttempt.last
      expected_transfer_attempt_attrs.each do |attr, val|
        expect(transfer_attempt[attr]).to eq val
      end
      expect(transfer_attempt.session_key).to_not be_nil
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
      ).and_call_original
      VCR.use_cassette('TransferDialerSuccessfulDial') do
        transfer_dialer.dial(caller_session)
      end
    end

    it 'returns a hash {type: transfer_type, status: ''}' do
      VCR.use_cassette('TransferDialerSuccessfulDial') do
        expect(transfer_dialer.dial(caller_session)).to eq({type: transfer.transfer_type, status: 'Ringing'})
      end
    end

    context 'the transfer succeeds' do
      it 'updates the transfer_attempt sid with the call_sid from the response' do
        VCR.use_cassette('TransferDialerSuccessfulDial') do
          transfer_dialer.dial(caller_session)
        end
        expect(transfer.transfer_attempts.last.sid).to match /\ACA\w+\Z/
      end
    end

    context 'the transfer fails' do
      before do
        transfer.update_attributes!({
          phone_number: twilio_invalid_to
        })
      end

      it 'updates the transfer_attempt status with "Call failed"' do
        VCR.use_cassette('TransferDialerFailedDial') do
          transfer_dialer.dial(caller_session)
        end
        expect(transfer.transfer_attempts.last.status).to eq 'Call failed'
      end
    end
  end
end
