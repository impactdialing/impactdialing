require 'spec_helper'

class SessionOrAttempt
  cattr_accessor :call_not_connected, :call_time
  attr_accessor :debited, :id

  include CallPayment

  def call_not_connected?
    self.class.call_not_connected
  end

  def call_time
    self.class.call_time
  end
end

describe CallPayment do
  let(:account){ mock_model('Account') }
  let(:campaign) do
    mock_model('Campaign', {
      account: account
    })
  end
  let(:subscription) do
    mock_model('Subscription', {
      account: account,
      debit: true
    })
  end
  let(:session_or_attempt) do
    SessionOrAttempt.new
  end

  before do
    session_or_attempt.stub(:campaign){ campaign }
    account.stub(:debitable_subscription){ subscription }
  end

  it 'loads the account that owns the associated campaign' do
    campaign.should_receive(:account){ account }
    session_or_attempt.debit
  end
  context 'the caller session or call attempt never connected' do
    before do
      SessionOrAttempt.call_not_connected = true
    end
    it 'sets self.debited to true' do
      session_or_attempt.debited.should be_false
      session_or_attempt.debit
      session_or_attempt.debited.should be_true
    end
    it 'returns self' do
      session_or_attempt.debit.should eq session_or_attempt
    end
  end
  context 'the caller session or call attempt did connect' do
    before do
      SessionOrAttempt.call_not_connected = false
      SessionOrAttempt.call_time = 50
    end
    it 'sets self.debited to the result of debiting a debitable_subscription' do
      session_or_attempt.debited.should be_false
      session_or_attempt.debit
      session_or_attempt.debited.should be_true
    end
  end

  context 'a debitable_subscription is not returned' do
    before do
      account.stub(:debitable_subscription){ nil }
      session_or_attempt.debited.should be_false
    end

    it 'sets SessionOrAttempt#debited to true and returns self' do
      session_or_attempt.debit
      session_or_attempt.debited.should be_true
    end
  end
end
