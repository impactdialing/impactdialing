require 'rails_helper'

describe 'CallFlow::DialQueue::Jobs::Purge.perform(campaign_id)' do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:available_households) do
    build_household_hashes(5, voter_list)
  end
  let(:recycled_households) do
    build_household_hashes(5, voter_list)
  end

  let(:set_keys_under_test) do
    [
      campaign.dial_queue.available.send(:keys)[:active],
      campaign.dial_queue.available.send(:keys)[:presented],
      campaign.dial_queue.recycle_bin.send(:keys)[:bin],
      campaign.dial_queue.completed.send(:keys)[:completed],
      campaign.dial_queue.blocked.send(:keys)[:blocked]
    ]
  end
  let(:hash_keys_root_under_test) do
    [
      campaign.dial_queue.households.keys[:active],
      campaign.dial_queue.households.keys[:inactive],
      campaign.dial_queue.households.keys[:presented]
    ]
  end
  let(:dial_queue){ campaign.dial_queue }

  before do
    import_list(voter_list, available_households.merge(recycled_households))
    set_keys_under_test.each do |key|
      redis.zadd key, [rand(10), Forgery(:address).clean_phone]
    end
    
    expect(dial_queue.households.exists?).to be_truthy
  end

  it 'removes all dial queue data for given campaign' do
    CallFlow::DialQueue::Jobs::Purge.perform(campaign.id)

    existing_redis_keys = redis.keys
    set_keys_under_test.each do |key|
      expect(existing_redis_keys).to_not include(key)
    end
    hash_keys_root_under_test.each do |key|
      expect(redis.keys("#{key}*")).to be_empty
    end
  end
end
