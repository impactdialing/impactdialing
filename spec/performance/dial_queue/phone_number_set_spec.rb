require 'rails_helper'

class Magic < CallFlow::DialQueue::PhoneNumberSet
  def keys
    {
      one: "this:thaat:1"
    }
  end

  def add
    redis.zadd keys[:one], Time.now.to_i, Forgery(:address).clean_phone
  end
end

describe CallFlow::DialQueue::PhoneNumberSet do
  let(:campaign){ create(:power) }

  subject{ Magic.new(campaign) }

  after do
    expect(redis.zcard(subject.keys[:one])).to eq 0
  end

  describe 'deleting 100 members' do
    before do
      100.times{ subject.add }
    end

    it 'can achieve 1k ops/sec' do
      expect{
        subject.purge!
      }.to be_faster_than 0.001
    end
  end
end
