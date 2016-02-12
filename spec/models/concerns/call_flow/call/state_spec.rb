require 'rails_helper'

describe 'CallFlow::Call::State' do
  let(:valid_base_key){ 'one:two:three' }
  let(:missing_part_base_key){ 'one:two' }
  let(:blank_part_base_key){ ':two:three' }
  let(:state){ 'pause' }

  subject{ CallFlow::Call::State.new(valid_base_key) }

  describe 'instantiation' do
    subject{ CallFlow::Call::State }

    it 'requires base_key w/ 3 non-blank parts' do
      expect(subject.new(valid_base_key)).to be_kind_of subject
    end

    it 'raises CallFlow::Call::State::InvalidBaseKey when base_key is invalid' do
      expect{
        subject.new(missing_part_base_key)
      }.to raise_error CallFlow::Call::InvalidBaseKey

      expect{
        subject.new(blank_part_base_key)
      }.to raise_error CallFlow::Call::InvalidBaseKey
    end
  end

  it 'tracks the state history of a call at redis key: "calls:#{account_sid}:#{call_sid}:state_history"' do
  end

  describe '#visited(state)' do
    it 'records the current time as string value under the "state" property of a redis hash' do
      Timecop.freeze do
        subject.visited(state)
        expect(redis.hget("#{valid_base_key}:state", state)).to eq Time.now.utc.to_s
      end
    end
  end

  describe '#visited?(state)' do
    before do
      subject.visited(state)
    end
    it 'returns true if the "state" property of the redis hash is set' do
      expect(subject.visited?(state)).to be_truthy
    end
    it 'returns false when the "state" property of the redis hash is not set' do
      expect(subject.visited?('oregon')).to be_falsey
    end
  end
end

