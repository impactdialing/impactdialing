require 'rails_helper'

describe CallList::Prune::Numbers do
  include ListHelpers
  let(:campaign){ create(:predictive) }
  let(:voter_list) do
    create(:voter_list, {
      campaign: campaign,
      purpose: 'import'
    })
  end
  let(:prune_voter_list) do
    create(:voter_list, {
      campaign: campaign,
      purpose: 'prune_numbers'
    })
  end
  let(:households) do
    build_household_hashes(5, voter_list)
  end
  let(:numbers_to_delete) do
    households.keys[0..2]
  end
  let(:numbers_to_keep) do
    households.keys[3..-1]
  end

  before do
    import_list(voter_list, households, 'active', 'active')
  end

  describe '#delete(numbers)' do
    subject{ CallList::Prune::Numbers.new(prune_voter_list) }
    let(:first_number){ numbers_to_delete.first }
    let(:last_number){ numbers_to_delete.last }

    def move_to(phone, dst)
      src = campaign.dial_queue.available.keys[:active]
      redis.zrem(src, phone)
      redis.zadd(dst, 1.1, phone)
    end

    context 'removing matching phone numbers from all sets' do
      after do
        expect(numbers_to_delete).to_not be_in_dial_queue_zset campaign.id, 'active' 
      end
      it 'active' do
        subject.delete(numbers_to_delete)
      end
      it 'presented' do
        key = campaign.dial_queue.available.keys[:presented]
        move_to(first_number, key)
        subject.delete(numbers_to_delete)
        expect(first_number).to_not be_in_dial_queue_zset campaign.id, 'presented'
      end
      it 'completed' do
        key = campaign.dial_queue.completed.keys[:completed]
        move_to(first_number, key)
        subject.delete(numbers_to_delete)
        expect(first_number).to_not be_in_dial_queue_zset campaign.id, 'completed'
      end
      it 'failed' do
        key = campaign.dial_queue.completed.keys[:failed]
        move_to(first_number, key)
        subject.delete(numbers_to_delete)
        expect(first_number).to_not be_in_dial_queue_zset campaign.id, 'failed'
      end
      it 'bin' do
        key = campaign.dial_queue.recycle_bin.keys[:bin]
        move_to(first_number, key)
        subject.delete(numbers_to_delete)
        expect(first_number).to_not be_in_dial_queue_zset campaign.id, 'bin'
      end
      it 'blocked' do
        key = campaign.dial_queue.blocked.keys[:blocked]
        move_to(first_number, key)
        subject.delete(numbers_to_delete)
        expect(first_number).to_not be_in_dial_queue_zset campaign.id, 'blocked'
      end
    end

    it 'returns count of numbers removed' do
      expect(subject.delete(numbers_to_delete)).to eq numbers_to_delete.size
    end

    it 'removes phone number & associated lead data from hash' do
      subject.delete(numbers_to_delete)
      houses = {}
      numbers_to_delete.each do |number|
        houses.merge!({number => households[number]})
      end
      expect(houses).to_not be_in_redis_households campaign.id, 'active'
    end

    it 'does not remove other phone numbers or leads' do
      subject.delete(numbers_to_delete)
      houses = {}
      numbers_to_keep.each do |phone|
        houses.merge!({phone => households[phone]})
      end
      expect(houses).to be_in_redis_households campaign.id, 'active'
    end

    context 'stats' do
      context 'campaign' do
        it 'decrements total_numbers' do
          subject.delete(numbers_to_delete)
          key = campaign.call_list.stats.key
          expect(redis.hget(key, 'total_numbers').to_i).to eq numbers_to_keep.size
        end
      end

      context 'list' do
        it 'increments total_numbers' do
          subject.delete(numbers_to_delete)
          key = prune_voter_list.stats.key
          expect(redis.hget(key, 'total_numbers').to_i).to eq numbers_to_delete.size
        end

        it 'increments removed_numbers' do
          subject.delete(numbers_to_delete)
          key = prune_voter_list.stats.key
          expect(redis.hget(key, 'removed_numbers').to_i).to eq numbers_to_delete.size
        end
      end
    end
  end
end

