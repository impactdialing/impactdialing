require 'rails_helper'

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
      @available = CallFlow::DialQueue::Available.new(campaign)
      @available.insert scored_members
      retries = -1
      begin
        @retrieved = @available.next(n)
      rescue CallFlow::DialQueue::Available::RedisTransactionAborted
        (retries += 1) < 5 ? retry : raise
      end
    end

    it 'returns the first "n" phone numbers from the "active" set' do
      expect(@retrieved.size).to eq n
    end

    it 'keeps retrieved numbers in presented list' do
      expect(@available.all(:presented)).to eq @retrieved
    end
  end
end

