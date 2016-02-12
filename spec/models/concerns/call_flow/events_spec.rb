require 'rails_helper'

describe 'CallFlow::Events' do
  let(:sequence){ 12 }
  let(:call_storage) do
    instance_double('CallFlow::Call::Storage', {
      incrby: sequence
    })
  end
  let(:caller_session_call) do
    instance_double('CallFlow::CallerSession', {
      sid: 'caller-session-sid',
      storage: call_storage,
      redis_expiry: 1.minute,
      expire: nil,
      redis: redis
    })
  end
  subject{ CallFlow::Events.new(caller_session_call) }

  it '#key => "call_flow:events:#{caller_session_call.sid}"' do
    expect(subject.key).to eq "call_flow:events:#{caller_session_call.sid}"
  end

  describe '#generate_sequence' do
    it 'tells storage to :incrby "event_sequence"' do
      expect(call_storage).to receive(:incrby).with('event_sequence', 1)
      subject.generate_sequence
    end

    it 'returns the incremented value' do
      expect(subject.generate_sequence).to eq sequence
    end
  end

  describe '#completed(event_sequence)' do
    it 'sets bit to 1 for event_sequence' do
      subject.completed(sequence)
      expect(redis.getbit(subject.key, sequence)).to eq 1
    end
  end

  describe '#completed?(event_sequence)' do
    it 'returns true when bit is set for event_sequence' do
      redis.setbit(subject.key, sequence, 1)
      expect(subject.completed?(sequence)).to be_truthy
    end
    it 'returns false when bit not set for event_sequence' do
      expect(subject.completed?(sequence)).to be_falsey
    end
  end
end
