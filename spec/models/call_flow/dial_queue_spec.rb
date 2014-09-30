require 'spec_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

  def clean_dial_queue_lists
    @dial_queue.clear(:available)
    # @dial_queue.clear(:dialed)
  end

  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
    ENV['DIAL_QUEUE_AVAILABLE_SEED_LIMIT'] = '5'
    ENV['DIAL_QUEUE_AVAILABLE_LIMIT'] = '10'
    @campaign = create_campaign_with_script(:bare_preview, account).last
    create_list(:realistic_voter, 100, {campaign: @campaign, account: account})
    @dial_queue = CallFlow::DialQueue.new(@campaign)
    @dial_queue.prepend
  end
  after do
    clean_dial_queue_lists
  end

  describe 'caching voters available to be dialed' do
    it 'caches ENV["DIAL_QUEUE_AVAILABLE_LIMIT"] number of voters' do
      expected = 10
      actual   = @dial_queue.size(:available)
      expect(actual).to eq expected
    end

    it 'preserves ordering of voters' do
      expected = @campaign.all_voters.select([:id, :phone]).order('id DESC').all[-10..-1].map{|voter| voter.to_json(root: false)}
      actual   = @dial_queue.peak(:available)
      expect(actual).to eq expected
    end

    it 'only caches voters that can be dialed right away' do
      @dial_queue.clear(:available)
      Voter.order('id DESC').limit(95).update_all(status: CallAttempt::Status::READY)
      @dial_queue.prepend

      expected = 5
      actual = @dial_queue.size(:available)
      expect(actual).to eq expected
    end
  end

  describe 'retrieving voters' do
    it 'retrieve one voter' do
      expected = [Voter.order('id').select([:id, :phone]).first.attributes]
      actual   = @dial_queue.next(1)

      expect(actual).to eq expected
    end

    it 'retrieves multiple voters' do
      expected = Voter.order('id').select([:id, :phone]).limit(10).map(&:attributes)
      actual   = @dial_queue.next(10)

      expect(actual).to eq expected
    end

    it 'removes retrieved voter(s) from queue' do
      voters     = @dial_queue.next(5)
      Voter.where(id: voters.map{|v| v['id']}).update_all(last_call_attempt_time: Time.now, status: CallAttempt::Status::BUSY)
      actual     = @dial_queue.available.peak.map{|v| JSON.parse(v)['id']}
      unexpected = voters.map{|v| v['id']}
      # binding.pry
      unexpected.each do |un|
        expect(actual).to_not include un
      end
    end

    context '(householding) more than one voter has the same phone number' do
      def attempt_recent_calls(voters)
        voters.each do |voter|
          @dial_queue.next(1)
          call_time = 5.minutes.ago
          voter.update_attribute('last_call_attempt_time', call_time)
          @dial_queue.household_dialed voter.phone, call_time
        end
      end

      before do
        clean_dial_queue_lists
        @voters = @campaign.all_voters
        @householders = [
          @voters[1],
          @voters[3],
          @voters[9]
        ]
        @householders.each do |voter|
          voter.update_attributes!(phone: '5551234567')
        end
        # load voters now that some are in same household
        @dial_queue.prepend
        attempted = [@voters[0], @voters[1], @voters[2]]
        not_called = @voters[3..9]
        attempt_recent_calls(attempted)
        @current_voter = attempted.last
      end
      after do
        clean_dial_queue_lists
      end

      context 'first voter in household has been called less than recycle_rate.hours.ago' do
        it 'does not load the second voter in the household' do
          expected = @voters[4]
          actual   = @dial_queue.next(1).first

          expect(actual['id']).to eq expected.id
        end
      end

      context 'first voter in household has been called more than recycle_rate.hours.ago' do
        it 'loads the second voter in the household' do
          attach_call_attempt(:past_recycle_time_completed_call_attempt, @voters[1])
          expected = @voters[3]
          actual = Voter.next_voter(@voters, @campaign.recycle_rate, [], @current_voter.id)

          expect(actual).to eq expected
        end
      end
    end

    describe 'robust to network failure' do
      context 'one or more result(s) were returned from redis server' do
        before do
          times_called = 0
          load_count   = 0
          redis        = @dial_queue.available.send(:redis)

          allow(redis).to receive(:rpop).exactly(:three) do
            times_called       += 1

            if times_called == 1
              voter = Voter.select([:id, :phone]).order('id').all[load_count]
              load_count += 1
              voter.to_json(root: false)
            elsif times_called >= 2
              msg = "redis.rpop called #{times_called} times"
              times_called = 0 if times_called == 4
              raise Redis::TimeoutError, msg
            end
          end
        end
        after do
          clean_dial_queue_lists
        end

        it 'returns the result(s)' do
          expected_size = 3
          expected_val  = Voter.select([:id, :phone]).order('id').limit(3).map(&:attributes)
          actual        = @dial_queue.next(3)

          expect(actual.size).to eq expected_size
          expect(actual).to eq expected_val
        end
      end

      context 'no results returned from server' do
        before do
          redis = @dial_queue.available.send(:redis)
          @times_called = 0
          allow(redis).to receive(:rpop).exactly(:nine) do
            @times_called += 1
            raise Redis::TimeoutError
          end
        end
        after do
          expect(@times_called).to eq 4
          clean_dial_queue_lists
        end

        it 're-raises exception' do
          expect{ @dial_queue.next(3) }.to raise_error(Redis::TimeoutError)
        end
      end
    end
  end

  describe 'seed' do
    before do
      clean_dial_queue_lists
    end
    after do
      clean_dial_queue_lists
    end
    it 'loads voters limited by ENV["DIAL_QUEUE_AVAILABLE_SEED_LIMIT"] which should be a small number to keep startup time fast' do
      @dial_queue.seed
      expect(@dial_queue.size(:available)).to eq 5
    end
  end

  describe 'clean up' do
    it 'expires queues at 10 minutes past the appropriate Campaign#end_time' do
      key      = @dial_queue.available.send(:keys)[:active]
      actual   = @dial_queue.available.send(:redis).ttl key

      today       = Date.today
      # campaign.end_time only stores the hour
      expire_time = Time.mktime(today.year, today.month, today.day, @campaign.end_time.hour, 10)

      expected = expire_time.in_time_zone(@campaign.time_zone).end_of_day.to_i - Time.now.in_time_zone(@campaign.time_zone).to_i

      expect(actual).to eq expected
    end
  end

  describe 'refreshing cache' do
    it 'is robust to network failure'
  end
end
