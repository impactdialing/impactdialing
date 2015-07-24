require 'rails_helper'

describe 'CallFlow::Call::Storage' do
  let(:redis){ Redis.new }
  let(:account_sid){ 'AC-123' }
  let(:call_sid){ 'CA-321' }
  let(:namespace){ 'sessions' }
  let(:base_key){ "calls:#{account_sid}:#{call_sid}" }
  let(:key_with_namespace){ "#{base_key}:#{namespace}" }

  subject{ CallFlow::Call::Storage.new(account_sid, call_sid) }

  describe 'instantiation' do
    subject{ CallFlow::Call::Storage }
    it 'returns a new instance given an account_sid, call_sid & optional namespace' do
      expect(subject.new(account_sid, call_sid)).to be_kind_of subject
      expect(subject.new(account_sid, call_sid, namespace)).to be_kind_of subject
    end
  end

  describe 'storing data' do
    before do
      subject[:sally] = 'Happy'
    end

    it 'provides :[]= to store a single property/value in redis' do
      expect(redis.hget(base_key, 'sally')).to eq 'Happy'
    end
    it 'provides :[] to read a single value at given property from redis' do
      expect(subject[:sally]).to eq 'Happy'
      expect(subject['sally']).to eq 'Happy'
    end
    it 'saves data to redis key "calls:{account_sid}:{call_sid}:{namespace}" when namespace is given' do
      storage = CallFlow::Call::Storage.new(account_sid, call_sid, namespace)
      storage[:total_dials] = 12
      expect(redis.hget(key_with_namespace, 'total_dials')).to eq "12"
    end

    describe '#save(hash)' do
      let(:hash) do
        {
          total_dials: 12,
          status: 'pending',
          yomickey: 'you so fine'
        }
      end
      it 'saves hash of key/string values to redis' do
        subject.save(hash)
        hash.each do |key,value|
          expect(redis.hget(base_key, key)).to eq value.to_s
        end
      end
    end
  end
end

