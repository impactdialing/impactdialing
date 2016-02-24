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

  shared_context 'a dialed number' do
    subject{ CallFlow::DialQueue.new(campaign) }
    let(:phone){ households.keys.first }
    before do
      redis.zadd subject.available.keys[:presented], 1.000001, phone
      expect(phone).to be_in_dial_queue_zset(campaign.id, 'presented')
    end
  end

  describe 'when a new number is blocked' do
    subject{ CallFlow::DialQueue.new(campaign) }
    let(:phone){ households.keys.first }
    let(:score){ 3.0 }
    
    context 'enable/disable list support (going away w/ future change)' do
      it 'updates inactive household' do
        house = subject.households.find phone
        hh    = CallFlow::DialQueue::Households.new(campaign, :inactive)
        redis.hset *hh.hkey(phone), house.to_json

        subject.update_blocked_property(phone, 1)

        house = hh.find phone
        expect(house['blocked']).to eq 1
      end
    end

    it 'adds given int to current blocked property int value for active household' do
      subject.update_blocked_property(phone, 1)
      house = subject.households.find phone
      expect(house['blocked']).to eq 1
    end

    it 'removes the phone from all available zsets' do
      redis.zadd subject.available.keys[:active], score, phone
      redis.zadd subject.available.keys[:presented], score, phone
      subject.update_blocked_property(phone, 1)
      expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'active')
      expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'inactive')
    end

    it 'removes the phone from recycle_bin zset' do
      redis.zadd subject.recycle_bin.keys[:bin], score, phone
      subject.update_blocked_property(phone, 1)
      expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'bin')
    end

    it 'adds the phone to the "blocked" zset' do
      subject.update_blocked_property(phone, 1)
      expect(phone).to be_in_dial_queue_zset campaign.id, 'blocked'
    end
  end

  describe 'when a number is un-blocked' do
    subject{ CallFlow::DialQueue.new(campaign) }
    let(:phone){ households.keys.first }
    
    before do
      subject.update_blocked_property(phone, 1)
      house = subject.households.find phone
      expect(house['blocked']).to eq 1
      subject.update_blocked_property(phone, -1)
    end

    it 'adds given int to current blocked property int value' do
      house = subject.households.find phone
      expect(house['blocked']).to eq 0
    end

    it 'adds the phone to the "bin" zset' do
      expect(phone).to be_in_dial_queue_zset(campaign.id, 'bin')
    end

    it 'removes the phone from the "blocked" zset' do
      expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'blocked')
    end
  end

  describe 'dialed_number_persisted(phone)' do
    include_context 'a dialed number'

    shared_examples_for 'any persisted dial' do
      it 'removes the phone from the available presented zset' do
        subject.dialed_number_persisted(phone, nil)
        expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'presented')
      end
    end

    shared_examples_for 'dials that are retried' do
      it 'adds the phone to the recycle_bin bin zset' do
        subject.dialed_number_persisted(phone, nil)
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'bin')
      end
    end

    shared_examples_for 'dials that are not retried' do
      it 'adds the phone to the completed completed zset' do
        subject.dialed_number_persisted(phone, nil)
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'completed')
      end
    end

    context 'Households#dial_again? => true' do
      before do
        allow(subject.households).to receive(:dial_again?){ true }
      end
      it_behaves_like 'any persisted dial'
      it_behaves_like 'dials that are retried'
    end

    context 'Households#dial_again? => false' do
      before do
        allow(subject.households).to receive(:dial_again?){ false }
      end
      it_behaves_like 'any persisted dial'
      it_behaves_like 'dials that are not retried'
    end
  end

  describe 'failed!(phone)' do
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

      it 'decrements presented count when :update_presented_count is true' do
        subject.failed!(phone, true)
        expect(campaign.presented_count).to be_zero
      end

      it 'does not decrement presented count when :update_presented_count is false' do
        subject.failed!(phone)
        expect(campaign.presented_count).to eq 1
      end

      it_behaves_like 'any failed dial'
    end
  end

  describe 'recycle the dial queue' do
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

      expect(actual.first[:leads]).to match expected.first[:leads].map(&:stringify_keys)
    end

    it 'retrieves multiple phone numbers' do
      phones = households.keys.sort_by{|ph| households[ph][:sequence]}[0..9]
      expected = []
      phones.each do |phone|
        expected << households[phone]
      end
      actual   = dial_queue.next(10)

      actual.each_with_index do |house, i|
        expect(house[:leads]).to match expected[i][:leads].map(&:stringify_keys)
      end
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
      before do
        phone = redis.zrange(dial_queue.available.keys[:active], 0, 0).first
        hkey  = dial_queue.households.hkey(phone)
        house = JSON.parse(redis.hget(*hkey))
        house['leads'] = []
        redis.hset *hkey, house.to_json
      end

      it 'raises CallFlow::DialQueue::EmptyHousehold' do
        expect{ dial_queue.next(1) }.to raise_error(CallFlow::DialQueue::EmptyHousehold)
      end

      context '1 household has no leads but others do' do
        it 'returns households with leads and ignores those without' do
          phone_two = redis.zrange(dial_queue.available.keys[:active], 1, 1).first
          houses = dial_queue.next(2)
          expect(houses.size).to eq 1

          expect(houses.first[:leads]).to match households[phone_two][:leads].map(&:stringify_keys)
        end
      end
    end

    context 'when no more phone numbers are found' do
      it 'returns nil' do
        key = dial_queue.available.keys[:active]
        phones = redis.zrange(key, 0, -1)
        redis.zrem key, phones

        expect(dial_queue.next(1)).to be_nil
      end
    end
  end

  describe 'removing all data from redis' do
    let(:phone){ Forgery(:address).clean_phone }
    let(:voter_list){ create(:voter_list, campaign: campaign) }

    before do
      redis.zadd dial_queue.available.keys[:active], 3.0, phone
      redis.zadd dial_queue.available.keys[:presented], 3.0, phone
      redis.zadd dial_queue.completed.keys[:completed], 3.0, phone
      redis.zadd dial_queue.blocked.keys[:blocked], 3.0, phone
      redis.zadd dial_queue.recycle_bin.keys[:bin], 3.0, phone
      redis.mapped_hmset dial_queue.campaign.call_list.stats.key, {total_numbers: 12, total_leads: 14}
      redis.mapped_hmset voter_list.stats.key, {total_numbers: 12, total_leads: 14}
      dial_queue.purge
    end

    it 'removes all data from Households' do
      key = dial_queue.households.send(:keys)[:active]
      expect(redis.keys("#{key}*")).to be_empty
    end

    it 'removes all data from RecycleBin' do
      key = dial_queue.recycle_bin.send(:keys)[:bin]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Completed' do
      key = dial_queue.completed.send(:keys)[:completed]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Blocked' do
      key = dial_queue.completed.send(:keys)[:blocked]
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

    it 'leaves campaign list stats (for archived reporting)' do
      expect(dial_queue.campaign.call_list.stats[:total_numbers]).to eq 12
    end

    it 'leaves all campaign voter lists stats (for archived reporting)' do
      expect(voter_list.stats[:total_numbers]).to eq 12
    end
  end
end
