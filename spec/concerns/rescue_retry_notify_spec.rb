require 'spec_helper'

class ExceptionClass < SocketError; end

describe RescueRetryNotify do
  let(:net_sum_match){ double }
  let(:mailer) do
    double({
      deliver_exception_notification: nil
    })
  end
  let(:attempt_limit){ 2 }
  before do
    allow(UserMailer).to receive(:new){ mailer }
  end

  describe '.on(ExceptionClass, attempt_limit){ call_to_retry }' do
    before do
      allow(net_sum_match).to receive(:call_to_retry).and_raise(ExceptionClass)
    end

    it 'raises ArgumentError if no block given' do
      expect{ RescueRetryNotify.on(ExceptionClass, attempt_limit) }.to raise_error(ArgumentError)
    end

    it 'rescues ExceptionClass up to attempt_limit times then re-raises ExceptionClass' do
      expect(net_sum_match).to receive(:call_to_retry).exactly(attempt_limit).times
      expect{ RescueRetryNotify.on(ExceptionClass, attempt_limit) do
        net_sum_match.call_to_retry
      end }.to raise_error(ExceptionClass)
    end

    it 'delivers an exception notification when attempt_limit is reached' do
      expect(mailer).to receive(:deliver_exception_notification)
      expect{ RescueRetryNotify.on(ExceptionClass, attempt_limit) do
        net_sum_match.call_to_retry
      end }.to raise_error(ExceptionClass)
    end
  end
end
