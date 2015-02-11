require 'spec_helper'

describe 'CallFlow::Call' do
  describe 'tracking the TwiML request history of a Call' do
    let(:twilio_params) do
      {
        'CallSid'    => 'CA123',
        'AccountSid' => 'AC432'
      }
    end
    let(:redis){ Redis.new }
    let(:key){ "calls:#{twilio_params['AccountSid']}:#{twilio_params['CallSid']}" }

    subject{ CallFlow::Call.new(twilio_params) }

    after do
      redis.flushall
    end

    it 'stores the state name as a hash key and current UTC time as value eg :incoming => "2015-02-09 01:23:57 UTC"' do
      Timecop.freeze do
        subject.update_history(:delirious)
        expect(redis.hget(key, :delirious)).to eq Time.now.utc.to_s
      end
    end
    it 'expires the key after 1 day' do
      subject.update_history(:expires)

      expect(redis.ttl(key)).to eq 86400
    end
    context 'asking if a state was visited' do
      before do
        subject.update_history(:whatnow)
      end
      it 'returns true if a value is returned for given state' do
        expect(subject.state_visited?(:whatnow)).to be_truthy
      end
      it 'returns false if a value is not returned for given state' do
        expect(subject.state_visited?(:bermuda)).to be_falsey
      end
      it 'returns false if there is no hash for the given key' do
        live_call = CallFlow::Call.new(twilio_params.merge('CallSid' => 'CA432'))
        expect(live_call.state_visited?(:whatnow)).to be_falsey
      end
    end
    context 'ask if a state was missed' do
      it 'returns true if a value is not returned for given state' do
        expect(subject.state_missed?(:mama)).to be_truthy
      end
    end
  end
end