require 'spec_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
    ENV['DIAL_QUEUE_AVAILABLE_SEED_LIMIT'] = '5'
    ENV['DIAL_QUEUE_AVAILABLE_LIMIT'] = '10'
    @campaign = create_campaign_with_script(:bare_preview, account).last
    create_list(:realistic_voter, 100, {campaign: @campaign, account: account})
    @dial_queue = CallFlow::DialQueue.new(@campaign)
    @dial_queue.prepend(:available)
  end
  after do
    @dial_queue.clear(:available)
  end

  describe 'caching voters available to be dialed' do
    it 'caches ENV["DIAL_QUEUE_AVAILABLE_LIMIT"] number of voters' do
      expected = 10
      actual   = @dial_queue.size(:available)
      expect(actual).to eq expected
    end

    it 'preserves ordering of voters' do
      expected = @campaign.all_voters.select([:id]).order('id DESC').all[-10..-1].map{|voter| voter.to_json(root: false)}
      actual   = @dial_queue.peak(:available)
      expect(actual).to eq expected
    end

    it 'only caches voters that can be dialed right away' do
      @dial_queue.clear(:available)
      Voter.order('id DESC').limit(95).update_all(status: CallAttempt::Status::READY)
      @dial_queue.prepend(:available)

      expected = 5
      actual = @dial_queue.size(:available)
      expect(actual).to eq expected
    end

    it 'occurs in background (not in same execution path as retrieving voters)'
  end

  describe 'retrieving voters' do
    it 'retrieve one voter' do
      expected = [Voter.order('id').select([:id]).first.attributes]
      actual   = @dial_queue.next(1)

      expect(actual).to eq expected
    end

    it 'retrieves multiple voters' do
      expected = Voter.order('id').select([:id]).limit(10).map(&:attributes)
      actual   = @dial_queue.next(10)

      expect(actual).to eq expected
    end

    it 'removes retrieved voter(s) from queue' do
      voters     = @dial_queue.next(5)
      Voter.where(id: voters.map{|v| v['id']}).update_all(last_call_attempt_time: Time.now, status: CallAttempt::Status::BUSY)
      actual     = @dial_queue.queues[:available].peak.map{|v| JSON.parse(v)['id']}
      unexpected = voters.map{|v| v['id']}
      # binding.pry
      unexpected.each do |un|
        expect(actual).to_not include un
      end
    end

    describe 'robust to network failure' do
      context 'one or more result(s) were returned from redis server' do
        before do
          times_called = 0
          redis        = @dial_queue.queues[:available].send(:redis)

          allow(redis).to receive(:rpop).exactly(:three) do
            times_called += 1
            if times_called == 1
              Voter.select([:id]).first.attributes
            elsif times_called >= 2
              raise [Redis::TimeoutError, Redis::ConnectionError, Redis::CannotConnectError].sample
            end
          end
        end

        it 'returns the result(s)' do
          expected_size = 1
          expected_val  = [Voter.select([:id]).first.attributes]
          actual        = @dial_queue.next(3)

          expect(actual.size).to eq expected_size
          expect(actual).to eq expected_val
        end
      end

      context 'no results returned from server' do
        before do
          redis = @dial_queue.queues[:available].send(:redis)
          @times_called = 0
          allow(redis).to receive(:rpop).exactly(:nine) do
            @times_called += 1
            raise [Redis::TimeoutError, Redis::ConnectionError, Redis::CannotConnectError].sample
          end
        end
        after do
          expect(@times_called).to eq 9
        end

        it 're-raises exception' do
          expect{ @dial_queue.next(3) }.to raise_error(Redis::BaseConnectionError)
        end
      end
    end
  end

  describe 'seed' do
    before do
      @dial_queue.clear :available
    end
    it 'loads voters limited by ENV["DIAL_QUEUE_AVAILABLE_SEED_LIMIT"] which should be a small number to keep startup time fast' do
      @dial_queue.seed :available
      expect(@dial_queue.size(:available)).to eq 5
    end
  end

  describe 'clean up' do
    it 'expires queues at the appropriate Campaign#end_time' do
      key      = @dial_queue.queues[:available].send(:keys)[:active]
      actual   = @dial_queue.queues[:available].send(:redis).ttl key
      expected = @campaign.end_time.in_time_zone(@campaign.time_zone).end_of_day.to_i - Time.now.in_time_zone(@campaign.time_zone).to_i

      expect(actual).to eq expected
    end
  end

  describe 'refreshing cache' do
    it 'is robust to network failure'
  end
end
