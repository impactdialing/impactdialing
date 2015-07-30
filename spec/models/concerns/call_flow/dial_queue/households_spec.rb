require 'rails_helper'

describe 'CallFlow::DialQueue::Households' do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households) do
    build_household_hashes(10, voter_list)
  end

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  def key(phone)
    subject.send(:hkey, phone)
  end

  before do
    import_list(voter_list, households)
  end

  after do
    redis.flushall
  end

  describe 'automatic message drops' do
    let(:redis_key){ "dial_queue:#{campaign.id}:households:message_drops" }
    let(:phone_one){ households.keys.last }
    let(:sequence_one){ households[phone_one]['sequence'] }

    before do
      subject.record_message_drop(sequence_one)
    end

    describe 'record when a message has been dropped' do
      context 'for a given sequence' do
        it 'sets bit to 1 for given household sequence' do
          expect(redis.getbit(redis_key, sequence_one)).to eq 1
        end
      end
      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }
        let(:sequence_two){ households[phone_two]['sequence'] }

        it 'sets bit to 1 for household sequence of given phone number' do
          subject.record_message_drop_by_phone(phone_two)
          expect(redis.getbit(redis_key, sequence_two)).to eq 1
        end
      end
    end

    describe 'detect if a message has been dropped' do
      context 'for a given sequence' do
        let(:sequence_two){ households[households.keys.first]['sequence'] }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped_recorded?(sequence_two)).to be_falsey
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped_recorded?(sequence_one)).to be_truthy
        end
      end

      context 'for a given phone number' do
        let(:phone_two){ households.keys.first }

        it 'returns true when bit for household sequence is 1' do
          expect(subject.message_dropped?(phone_one)).to be_truthy
        end
        it 'returns false when bit for household sequence is 0' do
          expect(subject.message_dropped?(phone_two)).to be_falsey
        end
      end
    end
  end

  describe 'existence' do
    it 'returns true when any households exist' do
      expect(subject.exists?).to be_truthy
    end

    it 'returns false otherwise' do
      Redis.new.flushall
      expect(subject.exists?).to be_falsey
    end
  end

  describe 'finding data for given phone number(s)' do
    let(:phone_one){ households.keys.first }
    let(:phone_two){ households.keys.last }
    let(:household_one){ HashWithIndifferentAccess.new(households[phone_one]) }
    let(:household_two){ HashWithIndifferentAccess.new(households[phone_two]) }

    describe 'finding a collection of members ids for a given phone number' do
      context 'the redis-key & hash-key of the phone number exist' do
        it 'return an array of members' do
          leads_one = subject.find(phone_one)[:leads]
          leads_two = subject.find(phone_two)[:leads]
          expect(leads_one).to eq household_one[:leads]
          expect(leads_two).to eq household_two[:leads]
        end
      end

      context 'the redis-key & hash-key of the phone number do not exist' do
        it 'return []' do
          actual = subject.find('1234567890')

          expect(actual).to eq []
        end
      end
    end

    describe 'finding one or more collections of member ids for one or more given phone numbers' do
      it 'return a hash where phone numbers are keys with each value a collection of member ids eg {"5554442211" => ["35","42"]}' do
        actual = subject.find_all([phone_one, phone_two])
        expected = {
          phone_one => household_one,
          phone_two => household_two
        }
        expect(actual).to eq expected
      end
    end
  end
end

