require 'rails_helper'

class ClassicPhoneSet < CallFlow::DialQueue::PhoneNumberSet
  def keys
    {
      one: "classic_phone_set:1",
      two: "classic_phone_set:2"
    }
  end

  def add(type, phone, score)
    redis.zadd keys[type], [score, phone]
  end
end

describe CallFlow::DialQueue::PhoneNumberSet do
  describe '#purge!' do
    def populate_set(type)
      10.times do |n|
        subject.add(type, Forgery(:address).clean_phone, n)
      end
    end

    let(:campaign){ create(:campaign) }

    subject{ ClassicPhoneSet.new(campaign) }

    before do
      populate_set :one
      populate_set :two
    end

    it 'deletes each set key from redis' do
      subject.purge!
      expect(redis.zcard(subject.keys[:one])).to be_zero
      expect(redis.zcard(subject.keys[:two])).to be_zero
    end
  end
end
