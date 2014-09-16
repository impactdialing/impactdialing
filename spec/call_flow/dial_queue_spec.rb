require 'spec_helper'

describe 'CallFlow::DialQueue' do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }

  before do
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
      expected = @campaign.all_voters.select([:id, :phone]).order('id DESC').all[-10..-1].map{|voter| voter.to_json(root: false)}
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
      @dial_queue.next(5)

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
end