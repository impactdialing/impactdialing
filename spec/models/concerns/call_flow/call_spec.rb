require 'rails_helper'

describe 'CallFlow::Call' do
  let(:twilio_params) do
    {
      'CallSid'    => 'CA123',
      'AccountSid' => 'AC432'
    }
  end
  let(:redis){ Redis.new }
  let(:key){ "calls:#{twilio_params['AccountSid']}:#{twilio_params['CallSid']}" }

  subject{ CallFlow::Call.new(twilio_params['AccountSid'], twilio_params['CallSid']) }

  after do
    redis.flushall
  end

  describe 'valid params' do
    let(:expected_error){ CallFlow::Call::InvalidParams }
    let(:valid_params) do
      {
        'sid' => 'CA123',
        'account_sid' => 'AC321'
      }
    end
    it 'requires #account_sid' do
      expect{
        CallFlow::Call.new('', 'CA123')
      }.to raise_error expected_error
    end
    it 'requires #call_sid' do
      expect{
        CallFlow::Call.new('AC321', nil)
      }.to raise_error expected_error
    end
  end
end

