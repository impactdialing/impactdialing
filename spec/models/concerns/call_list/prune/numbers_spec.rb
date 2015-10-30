require 'rails_helper'

describe CallList::Prune::Numbers do
  include ListHelpers
  let(:campaign){ create(:predictive) }
  let(:voter_list) do
    create(:voter_list, {
      campaign: campaign
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
    subject{ CallList::Prune::Numbers.new(voter_list) }
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

    it 'removes phone number & associated lead data from hash' do
    end
  end
end
