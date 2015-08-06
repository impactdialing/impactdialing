require 'rails_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData
  include ListHelpers

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create_campaign_with_script(:bare_preview, account).last }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households) do
    build_household_hashes(20, voter_list)
  end
  let(:dial_queue){ campaign.dial_queue }

  before do
    Redis.new.flushall
    import_list(voter_list, households)
  end

  describe 'raise ArgumentError if initialized w/ invalid record' do
    it 'nil' do
      expect{
        CallFlow::DialQueue.new
      }.to raise_error{
        ArgumentError
      }
    end
    it 'no id' do
      record = double('Campaign', {id: nil, account_id: 42, recycle_rate: 1})
      expect{
        CallFlow::DialQueue.new(record)
      }.to raise_error{
        ArgumentError
      }
    end
    it 'no account_id' do
      record = double('Campaign', {id: 42, account_id: nil, recycle_rate: 1})
      expect{
        CallFlow::DialQueue.new(record)
      }.to raise_error{
        ArgumentError
      }
    end
    it 'no recycle_rate' do
      record = double('Campaign', {id: 42, account_id: 42})
      expect{
        CallFlow::DialQueue.new(record)
      }.to raise_error{
        ArgumentError
      }
    end
  end

  describe 'failed!(phone)' do
    let(:redis){ Redis.new }

    shared_context 'a dialed number' do
      subject{ CallFlow::DialQueue.new(campaign) }
      let(:phone){ Forgery('address').clean_phone }
      before do
        redis.zadd subject.available.keys[:presented], 1.000001, phone
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'presented')
      end
    end

    shared_examples_for 'any failed dial' do
      it 'removes the phone from the available presented zset' do
        subject.failed!(phone)
        expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'presented')
      end

      it 'adds the phone to the failed zset' do
        subject.failed!(phone)
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'failed')
      end
    end

    context 'when Preview or Power campaigns' do
      let(:campaign){ create(:preview) }

      include_context 'a dialed number'

      it 'does not decrement presented count' do
        subject.failed!(phone)
        expect(campaign.presented_count).to be_zero
      end
      
      it_behaves_like 'any failed dial'
    end

    context 'when Predictive campaign' do
      let(:campaign){ create(:predictive) }

      include_context 'a dialed number'

      before do
        Twillio::InflightStats.new(campaign).incby 'presented', 1
        expect(campaign.presented_count).to eq 1
      end

      it 'decrements presented count' do
        subject.failed!(phone)
        expect(campaign.presented_count).to be_zero
      end

      it_behaves_like 'any failed dial'
    end
  end

  describe 'recycle the dial queue' do
    let(:redis){ Redis.new }
    let(:caller){ create(:caller, campaign: campaign, account: account)}

    before do
      expect(dial_queue.available.size).to eq 20
      recycle_key       = dial_queue.recycle_bin.send(:keys)[:bin]
      presented_key     = dial_queue.available.send(:keys)[:presented]
      expired_score     = (campaign.recycle_rate + 1).hours.ago.to_i
      not_expired_score = Time.now.to_i

      10.times do |n|
        household = campaign.next_in_dial_queue
        phone     = household[:leads].first[:phone]
        cur_score = redis.zscore presented_key, phone
        id        = cur_score.to_s.split('.').last

        if n % 2 == 0
          score = "#{expired_score}.#{id}"
        else
          score = "#{not_expired_score}.#{id}"
        end

        redis.zadd(recycle_key, [score, phone])
        redis.zrem(presented_key, phone)
      end
      # sanity check 
      expect(dial_queue.available.size).to eq 10
      expect(dial_queue.recycle_bin.size).to eq 10

      # behavior under test
      dial_queue.recycle!
    end
    
    it 'add recyclable phone numbers to available set' do
      expect(dial_queue.available.size).to eq 15
    end

    it 'removes recyclable phone numbers from recycle bin set' do
      expect(dial_queue.recycle_bin.size).to eq 5
    end
  end

  describe 'dialing through available' do
    let(:phone){ households.keys.first }

    it 'retrieve one household' do
      expected = [households[phone]]
      actual   = dial_queue.next(1)

      expect(actual).to match expected
    end

    it 'retrieves multiple phone numbers' do
      phones = households.keys.sort_by{|ph| households[ph][:sequence]}[0..9]
      expected = []
      phones.each do |phone|
        expected << households[phone]
      end
      actual   = dial_queue.next(10)

      expect(actual).to match expected
    end

    it 'moves retrieved phone number(s) from :active queue to :presented' do
      houses           = dial_queue.next(5)
      remaining_phones = dial_queue.available.all(:active, with_scores: false)
      presented_phones = dial_queue.available.all(:presented, with_scores: false)

      houses.each do |house|
        phone = house[:leads].first[:phone]
        expect(presented_phones).to include phone
        expect(remaining_phones).to_not include phone
      end
    end

    context 'when a household has no leads in redis for presentation' do
      it 'raises CallFlow::DialQueue::EmptyHousehold' do
        phone = Redis.new.zrange(dial_queue.available.keys[:active], 0, 0).first
        dial_queue.households.save(phone, [])

        expect{ dial_queue.next(1) }.to raise_error(CallFlow::DialQueue::EmptyHousehold)
      end
    end

    context 'when no more phone numbers are found' do
      it 'returns nil' do
        redis = Redis.new
        key = dial_queue.available.keys[:active]
        phones = redis.zrange(key, 0, -1)
        redis.zrem key, phones

        expect(dial_queue.next(1)).to be_nil
      end
    end
  end

  describe 'removing all data from redis' do
    let(:redis){ Redis.new }

    before do
      @expected_purge_count = dial_queue.available.size + 
                              dial_queue.available.all(:presented).size +
                              dial_queue.recycle_bin.size
      @result = dial_queue.purge
    end

    it 'removes all data from Households' do
      key = dial_queue.households.send(:keys)[:active]
      expect(redis.keys("#{key}*")).to be_empty
    end

    it 'removes all data from RecycleBin' do
      key = dial_queue.recycle_bin.send(:keys)[:bin]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Available:active' do
      key = dial_queue.available.send(:keys)[:active]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Available:presented' do
      key = dial_queue.available.send(:keys)[:presented]
      expect(redis.keys).to_not include(key)
    end

    it 'returns count of household keys purged' do
      expect(@result).to eq @expected_purge_count
    end
  end
end
