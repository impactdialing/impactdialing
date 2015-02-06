require 'spec_helper'

describe 'CallFlow::DialQueue::Jobs::Purge.perform(campaign_id)' do
  let(:campaign){ create(:power) }
  let!(:available_voters){ create_list(:voter, 5, campaign: campaign) }
  let!(:recycled_voters){ create_list(:voter, 5, campaign: campaign) }

  let(:set_keys_under_test) do
    [
      campaign.dial_queue.available.send(:keys)[:active],
      campaign.dial_queue.available.send(:keys)[:presented],
      campaign.dial_queue.recycle_bin.send(:keys)[:bin]
    ]
  end
  let(:hash_key_root_under_test) do
    campaign.dial_queue.households.send(:keys)[:active]
  end
  let(:dial_queue){ campaign.dial_queue }

  before do
    Redis.new.flushall

    recycled_voters.each do |voter|
      voter.household.update_attributes!({
        presented_at: 10.minutes.ago,
        status: CallAttempt::Status::BUSY
      })
    end

    dial_queue.cache_all(campaign.reload.all_voters)
    dial_queue.next(1)
    expect(dial_queue.available.all.size).to eq 4
    expect(dial_queue.available.all(:presented).size).to eq 1
    expect(dial_queue.recycle_bin.size).to eq 5
    expect(dial_queue.households.exists?).to be_truthy
  end

  it 'removes all dial queue data for given campaign' do
    CallFlow::DialQueue::Jobs::Purge.perform(campaign.id)

    redis = Redis.new
    existing_redis_keys = redis.keys
    set_keys_under_test.each do |key|
      expect(existing_redis_keys).to_not include(key)
    end

    expect(redis.keys("#{hash_key_root_under_test}*")).to be_empty
  end
end
