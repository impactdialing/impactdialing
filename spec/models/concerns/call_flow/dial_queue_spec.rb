require 'rails_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
    Redis.new.flushall
    @campaign = create_campaign_with_script(:bare_preview, account).last
    create_list(:voter, 20, {campaign: @campaign, account: account})
    @dial_queue = CallFlow::DialQueue.new(@campaign)
    @dial_queue.cache_all(@campaign.all_voters)
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
      it 'removes the phone from the available (presented or active) zset' do
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

  describe 'caching voters available to be dialed' do
    it 'preserves ordering of voters' do
      expected = @campaign.households.map(&:phone)
      actual   = @dial_queue.available.all

      expect(actual).to eq expected
    end

    context 'partitioning voters by available state' do
      before do
        Redis.new.flushall
        # last 90 were busy
        Household.order('id DESC').limit(10).update_all(status: CallAttempt::Status::BUSY, presented_at: 5.minutes.ago)
        li = Household.order('id DESC').limit(10).last.id
        # 5 before that completed and are done
        households = Household.order('id DESC').where('id < ?', li).limit(5)
        households.update_all(status: CallAttempt::Status::SUCCESS, presented_at: 2.minutes.ago)
        households.each{|household| household.voters.update_all(status: CallAttempt::Status::SUCCESS)}
        @household_with_2_members       = households.reload.first
        @other_household_with_2_members = households.reload.last
        @that_household_with_2_members  = households.reload[2]
        @household_with_voicemail       = households.reload[3]

        @household_with_voicemail.update_attributes!(status: CallAttempt::Status::VOICEMAIL)
        @household_with_voicemail.voters.update_all(status: CallAttempt::Status::VOICEMAIL)
        # campaign config'd to not call back after voicemail
        create(:bare_call_attempt, :voicemail_delivered, {
          campaign: @campaign,
          household: @household_with_voicemail
        })

        @not_dialed_voter = create(:voter, {
          campaign: @campaign,
          account: account,
          household: @household_with_2_members
        })
        @abandoned_voter = create(:voter, {
          campaign: @campaign,
          account: account,
          household: @other_household_with_2_members,
          status: CallAttempt::Status::ABANDONED
        })
        @failed_voter = create(:voter, {
          campaign: @campaign,
          account: account,
          household: @that_household_with_2_members,
          status: CallAttempt::Status::FAILED
        })

        voters = @campaign.reload.all_voters
        @dial_queue.cache_all(voters) # 5 available, 30 recycled
      end

      it 'pushes phone numbers that cannot be dialed right away to the recycle bin set' do
        expect(@dial_queue.size(:recycle_bin)).to eq 12 # @(other_)household_with_2_members will be recycled
      end

      it 'pushes phone numbers that can be dialed right away to the available set' do
        expect(@dial_queue.size(:available)).to eq 5
      end

      it 'avoids pushing members that are not available for dial and not eventually retriable' do
        cached_members = @dial_queue.households.find(@household_with_2_members.phone)
        expect(cached_members.size).to eq 1
        expect(cached_members.first['id']).to eq @not_dialed_voter.id
      end

      context 'handling legacy Voter#status values' do
        it 'caches members that have been called but not completed' do
          cached_members = @dial_queue.households.find(@other_household_with_2_members.phone)
          expect(cached_members.size).to eq 1
          expect(cached_members.first['id']).to eq @abandoned_voter.id
        end

        it 'does not cache members that have failed' do
          cached_members = @dial_queue.households.find(@that_household_with_2_members)
          expect(cached_members.size).to eq 0
        end

        it 'does not cache members w/ voicemail delivered (household.cache? should return false)' do
          cached_members = @dial_queue.households.find(@household_with_voicemail.phone)
          expect(cached_members.size).to eq 0
        end
      end
    end
  end

  describe 'recycle the dial queue' do
    let(:account){ create(:account) }
    let(:admin){ create(:user, account: account) }
    let(:campaign){ create(:power, account: account) }
    let(:caller){ create(:caller, campaign: campaign, account: account)}

    before do
      add_voters(campaign, :voter, 10)
      @dial_queue = cache_available_voters(campaign)

      10.times do |n|
        house = campaign.next_in_dial_queue
        household = campaign.households.where(phone: house[:phone]).first
        call_attempt = if n <= 4
                          create(:past_recycle_time_busy_call_attempt, household: household, campaign: campaign)
                        else
                          create(:completed_call_attempt, household: household, voter: household.voters.first, campaign: campaign)
                        end
        household.dialed(call_attempt)
        household.save!
      end
      # sanity check that all were dialed
      expect(@dial_queue.available.size).to eq 0
      expect(@dial_queue.recycle_bin.size).to eq 10

      # behavior under test
      @dial_queue.recycle!
    end
    
    it 'add recyclable phone numbers to available set' do
      expect(@dial_queue.available.size).to eq 5
    end

    it 'removes recyclable phone numbers from recycle bin set' do
      expect(@dial_queue.recycle_bin.size).to eq 5
    end
  end

  describe 'remove a Voter record' do
    let(:voterA){ @campaign.all_voters.to_a[0] }
    let(:voterB){ @campaign.all_voters.to_a[1] }

    before do
      Redis.new.flushall
      voterB.update_attributes!(household: voterA.household)
      @dial_queue.cache_all(@campaign.all_voters.reload)

      expect(@dial_queue.households.find(voterA.household.phone).size).to eq 2

      @dial_queue.remove(voterA)
      @remaining_voters = @dial_queue.households.find(voterA.household.phone)
    end

    it 'removes the Voter record from the cache' do
      expect(@remaining_voters.map{|v| v['id']}).not_to include(voterA.id)
    end

    it 'leaves other Voter records from same household in the cache' do
      expect(@remaining_voters.first['id']).to eq voterB.id
    end

    context 'when last Voter record from a household is removed' do
      before do
        @dial_queue.recycle_bin.add(voterB.household)
        Redis.new.zadd(@dial_queue.available.send(:keys)[:presented], [[Time.now.to_i, voterB.household.phone]])
        expect(@dial_queue.available.all).to include(voterB.household.phone)
        expect(@dial_queue.available.all(:presented)).to include(voterB.household.phone)
        expect(@dial_queue.recycle_bin.all).to include(voterB.household.phone)
        
        @dial_queue.remove(voterB)
      end
      it 'removes the Household phone number from available active cache' do
        expect(@dial_queue.available.all).not_to include(voterB.household.phone)
      end

      it 'removes the Household phone number from available presented cache' do
        expect(@dial_queue.available.all(:presented)).not_to include(voterB.household.phone)
      end

      it 'removes the Household phone number from the recycle bin cache' do
        expect(@dial_queue.recycle_bin.all).not_to include(voterB.household.phone)
      end
    end
  end

  describe 'dialing through available' do
    it 'retrieve one household' do
      expected = [{
        phone: Household.first.phone,
        voters: Household.first.voters.map{|v| v.cache_data.stringify_keys}
      }]
      actual   = @dial_queue.next(1)

      expect(actual).to eq expected
    end

    it 'retrieves multiple phone numbers' do
      expected = []
      Household.limit(10).each do |household|
        expected << {
          phone: household.phone,
          voters: household.voters.map(&:cache_data).map(&:stringify_keys)
        }
      end
      actual   = @dial_queue.next(10)

      expect(actual).to eq expected
    end

    it 'moves retrieved phone number(s) from :active queue to :presented' do
      houses           = @dial_queue.next(5)
      remaining_phones = @dial_queue.available.all(:active, with_scores: false)
      presented_phones = @dial_queue.available.all(:presented, with_scores: false)

      houses.each do |house|
        phone = house[:phone]
        expect(presented_phones).to include phone
        expect(remaining_phones).to_not include phone
      end
    end

    context 'when a household has no leads in redis for presentation' do
      it 'raises CallFlow::DialQueue::EmptyHousehold' do
        phone = Redis.new.zrange(@dial_queue.available.keys[:active], 0, 0).first
        @dial_queue.households.save(phone, [])

        expect{ @dial_queue.next(1) }.to raise_error(CallFlow::DialQueue::EmptyHousehold)
      end
    end

    context 'when no more phone numbers are found' do
      it 'returns nil' do
        redis = Redis.new
        key = @dial_queue.available.keys[:active]
        phones = redis.zrange(key, 0, -1)
        redis.zrem key, phones

        expect(@dial_queue.next(1)).to be_nil
      end
    end
  end

  describe 'removing all data from redis' do
    let(:redis){ Redis.new }

    before do
      @expected_purge_count = @dial_queue.available.size + 
                              @dial_queue.available.all(:presented).size +
                              @dial_queue.recycle_bin.size
      @result = @dial_queue.purge
    end

    it 'removes all data from Households' do
      key = @campaign.dial_queue.households.send(:keys)[:active]
      expect(redis.keys("#{key}*")).to be_empty
    end

    it 'removes all data from RecycleBin' do
      key = @campaign.dial_queue.recycle_bin.send(:keys)[:bin]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Available:active' do
      key = @campaign.dial_queue.available.send(:keys)[:active]
      expect(redis.keys).to_not include(key)
    end

    it 'removes all data from Available:presented' do
      key = @campaign.dial_queue.available.send(:keys)[:presented]
      expect(redis.keys).to_not include(key)
    end

    it 'returns count of household keys purged' do
      expect(@result).to eq @expected_purge_count
    end
  end
end
