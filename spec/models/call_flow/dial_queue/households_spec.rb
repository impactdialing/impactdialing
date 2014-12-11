require 'spec_helper'

describe 'CallFlow::DialQueue::Households' do
  include DialQueueHelpers

  let(:campaign){ create(:power) }
  let(:phone_with_country_code){ '15554326847' }
  let(:phone_without_country_code){ '5554323829' }
  let(:member_with_country_code){ {'id' => 42} }
  let(:member_without_country_code){ {'id' => 43} }
  let(:member_of_country_code){ {'id' => 44} }

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  def key(phone)
    subject.send(:hkey, phone)
  end

  after do
    redis.flushall
  end

  describe 'adding a member from the collection' do
    it 'add the member to the collection' do
      subject.add(phone_with_country_code, member_with_country_code)

      actual = redis.hget *key(phone_with_country_code)
      expect(actual).to eq [member_with_country_code].to_json
    end

    it 'stores a collection in same order as added' do
      subject.add(phone_with_country_code, member_of_country_code)
      subject.add(phone_with_country_code, member_with_country_code)

      actual = redis.hget *key(phone_with_country_code)
      expect(actual).to eq [member_of_country_code, member_with_country_code].to_json
    end
  end

  describe 'removing a member from the collection' do
    it 'remove the member from the collection' do
      subject.add(phone_with_country_code, member_with_country_code)
      subject.add(phone_with_country_code, member_of_country_code)
      subject.remove_member(phone_with_country_code, member_with_country_code)

      actual = redis.hget *key(phone_with_country_code)
      expect(actual).to eq [member_of_country_code].to_json
    end
  end

  describe 'finding a collection of members ids for a given phone number' do
    context 'the redis-key & hash-key of the phone number exist' do
      it 'return an array of member ids' do
        subject.add(phone_with_country_code, member_with_country_code)
        subject.add(phone_with_country_code, member_of_country_code)
        subject.add(phone_without_country_code, member_without_country_code)

        with_country_code    = subject.find(phone_with_country_code)
        without_country_code = subject.find(phone_without_country_code)

        expect(with_country_code).to eq [member_with_country_code, member_of_country_code]
        expect(without_country_code).to eq [member_without_country_code]
      end
    end

    context 'the redis-key & hash-key of the phone number do not exist' do
      it 'return []' do
        actual = subject.find(phone_with_country_code)

        expect(actual).to eq []
      end
    end
  end

  describe 'finding one or more collections of member ids for one or more given phone numbers' do
    it 'return a hash where phone numbers are keys with each value a collection of member ids eg {"5554442211" => ["35","42"]}' do
      subject.add(phone_with_country_code, member_with_country_code)
      subject.add(phone_with_country_code, member_of_country_code)
      subject.add(phone_without_country_code, member_without_country_code)

      actual = subject.find_all([phone_with_country_code, phone_without_country_code])
      expected = {
        phone_with_country_code => [member_with_country_code, member_of_country_code],
        phone_without_country_code => [member_without_country_code]
      }
      expect(actual).to eq expected
    end
  end
end