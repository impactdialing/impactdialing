require 'spec_helper'

describe 'CallFlow::DialQueue::Available' do
  let(:phone_numbers) do
    20.times.map{ Forgery(:address).phone }
  end
  let(:scored_members) do
    phone_numbers.map{|phone| ["0.1", phone]}
  end
  let(:campaign) do
    double('Campaign', {id: 42, account_id: 42, recycle_rate: 1})
  end
  describe 'retrieve the next N numbers from active list' do
    let(:n){ 10 }

    before do
      Redis.new.flushall
      @available = CallFlow::DialQueue::Available.new(campaign)
      @available.insert scored_members
      @retrieved = @available.next(n)
    end

    it 'returns the first "n" phone numbers from the "active" set' do
      expect(@retrieved.size).to eq n
    end

    it 'keeps retrieved numbers in presented list' do
      expect(@available.all(:presented)).to eq @retrieved
    end

    context 'when the active list changes during retrieval' do
      it 'raises CallFlow::DialQueue::Available::RedisTransactionAborted' do
        key = @available.send(:keys)[:active]
        Thread.new(key) do |key|
          client = Redis.new
          15.times do
            client.zadd key, ["0.1", phone_numbers.first]
          end
        end
        expect{
          @available.next(1)
        }.to raise_error{
          CallFlow::DialQueue::Available::RedisTransactionAborted
        }
      end
    end
  end
end
