require 'spec_helper'

describe Debit do
  let(:call_time) do
    mock_model('CallTime', {
      :debited => false,
      :debited= => nil,
      :tDuration => nil,
      :tStartTime => nil,
      :tEndTime => nil
    })
  end
  let(:quota) do
    mock_model('Quota', {
      :debit => nil
    })
  end
  let(:account) do
    mock_model('Account', {
      quota: quota
    })
  end

  describe "#process" do
    let(:debit){ Debit.new(call_time, quota) }
    before do
      call_time.stub(:tStartTime){ 20.minutes.ago }
      call_time.stub(:tEndTime){ 15.minutes.ago }
      call_time.stub(:tDuration){ 5 * 60 }
    end

    it 'debits the call_time tDuration in minutes from quota' do
      quota.should_receive(:debit).with(5){ true }
      call_time.should_receive(:debited=).with(true)
      debit.process
    end

    it 'returns the call_time object' do
      debit.process.should eq call_time
    end
  end
end
