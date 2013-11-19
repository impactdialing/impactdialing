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
    UserMailer.stub(:new){ mailer }
  end

  describe '.on(ExceptionClass, attempt_limit){ call_to_retry }' do
    before do
      net_sum_match.stub(:call_to_retry).and_raise(ExceptionClass)
    end

    it 'raises ArgumentError if no block given' do
      lambda{ RescueRetryNotify.on(ExceptionClass, attempt_limit) }.should raise_error(ArgumentError)
    end

    it 'rescues ExceptionClass up to attempt_limit times then re-raises ExceptionClass' do
      net_sum_match.should_receive(:call_to_retry).exactly(attempt_limit).times
      lambda{ RescueRetryNotify.on(ExceptionClass, attempt_limit) do
        net_sum_match.call_to_retry
      end }.should raise_error(ExceptionClass)
    end

    it 'delivers an exception notification when attempt_limit is reached' do
      mailer.should_receive(:deliver_exception_notification)
      lambda{ RescueRetryNotify.on(ExceptionClass, attempt_limit) do
        net_sum_match.call_to_retry
      end }.should raise_error(ExceptionClass)
    end
  end
end
