require 'spec_helper'

describe 'CallFlow::DialQueue::Households' do
  include DialQueueHelpers

  let(:campaign){ create(:power) }
  let(:member_with_country_code){ double('Voter', {id: 42, phone: '15554326847'}) }
  let(:member_without_country_code){ double('Voter', {id: 43, phone: '5554323829'}) }
  let(:member_of_country_code){ double('Voter', {id: 44, phone: member_with_country_code.phone}) }

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  def key(phone)
    subject.send(:hkey, phone)
  end

  describe 'adding a member from the collection' do
    it 'add the member.id to the collection of member ids' do
      subject.add(member_with_country_code)

      actual = redis.hget *key(member_with_country_code.phone)
      expect(actual).to eq [member_with_country_code.id].to_json
    end

    it 'store a sorted collection of ids in ascending order' do
      subject.add(member_of_country_code)
      subject.add(member_with_country_code)

      actual = redis.hget *key(member_of_country_code.phone)
      expect(actual).to eq [member_with_country_code.id, member_of_country_code.id].to_json
    end
  end

  describe 'removing a member id from the collection' do
    it 'remove the id from the collection of member ids' do
      subject.add(member_with_country_code)
      subject.add(member_of_country_code)
      subject.remove(member_with_country_code)

      actual = redis.hget *key(member_of_country_code.phone)
      expect(actual).to eq [member_of_country_code.id].to_json
    end
  end

  describe 'finding a collection of members ids for a given phone number' do
    context 'the redis-key & hash-key of the phone number exist' do
      it 'return an array of member ids' do
        subject.add(member_with_country_code)
        subject.add(member_of_country_code)
        subject.add(member_without_country_code)

        with_country_code    = subject.find(member_with_country_code.phone)
        without_country_code = subject.find(member_without_country_code.phone)

        expect(with_country_code).to eq [member_with_country_code.id, member_of_country_code.id]
        expect(without_country_code).to eq [member_without_country_code.id]
      end
    end

    context 'the redis-key & hash-key of the phone number do not exist' do
      it 'return []' do
        actual = subject.find(member_with_country_code.phone)

        expect(actual).to eq []
      end
    end
  end

  describe 'finding one or more collections of member ids for one or more given phone numbers' do
    it 'return a hash where phone numbers are keys with each value a collection of member ids eg {"5554442211" => ["35","42"]}' do
      subject.add(member_with_country_code)
      subject.add(member_of_country_code)
      subject.add(member_without_country_code)

      actual = subject.find_all([member_of_country_code.phone, member_without_country_code.phone])
      expected = {
        member_of_country_code.phone => [member_with_country_code.id, member_of_country_code.id],
        member_without_country_code.phone => [member_without_country_code.id]
      }
      expect(actual).to eq expected
    end
  end
end