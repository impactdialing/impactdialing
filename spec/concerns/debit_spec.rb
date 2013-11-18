require 'spec_helper'

describe Debit do
  let(:mailer) do
    double('UserMailer', {
      :alert_email => nil
    })
  end
  let(:account){ mock_model('Account') }
  let(:call_time) do
    mock_model('CallTime', {
      :debited => false,
      :debited= => nil,
      :tDuration => nil,
      :tStartTime => nil,
      :tEndTime => nil
    })
  end
  let(:subscription) do
    mock_model('Subscription', {
      :debit => nil
    })
  end

  before do
    UserMailer.stub(:new){ mailer }
  end

  describe "#process" do
    context 'when call_time subscription is nil' do
      let(:debit){ Debit.new(call_time, account, nil) }

      it 'records call_time as being debited' do
        call_time.should_receive(:debited=).with(true)
        debit.process
      end

      it 'returns the call_time object' do
        debit.process.should eq call_time
      end

      it 'sends an alert email' do
        mailer.should_receive(:alert_email)
        debit.process
      end
    end

    context 'when call_time subscription is not nil' do
      let(:debit){ Debit.new(call_time, account, subscription) }
      before do
        call_time.stub(:tStartTime){ 20.minutes.ago }
        call_time.stub(:tEndTime){ 15.minutes.ago }
        call_time.stub(:tDuration){ 5 * 60 }
      end

      it 'debits the call_time tDuration in minutes from subscription' do
        subscription.should_receive(:debit).with(5){ true }
        call_time.should_receive(:debited=).with(true)
        debit.process
      end

      it 'returns the call_time object' do
        debit.process.should eq call_time
      end
    end
  end
end
