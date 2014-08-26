require 'spec_helper'

describe 'CalculateDialsJob' do
  include FakeCallData

  let(:admin) do
    create(:user)
  end
  let(:campaign) do
    create_campaign_with_script(:predictive, admin.account).last
  end

  def campaign_is_calculating_dials!(campaign)
    campaign.set_calculate_dialing
    expect(campaign.calculate_dialing?).to be_truthy
  end

  describe '.perform(campaign_id)' do
    before do
      add_voters(campaign, :realistic_voter, 25)
      add_callers(campaign, 5)
    end

    after do
      Resque.remove_queue :dialer_worker
    end

    it 'removes "dial_calculate:#{campaign_id}" key from Redis, such that Campaign#calculate_dialing? returns false' do
      campaign_is_calculating_dials!(campaign)

      CalculateDialsJob.perform(campaign.id)

      expect(campaign.calculate_dialing?).to be_falsy
    end

    context 'no dials have been made recently and there are no ringing lines' do
      before do
        campaign.callers.each do |caller|
          create(:bare_caller_session, :available, :webui, {
            campaign: campaign, caller: caller
          })
        end
      end

      it 'queues DialerJob w/ campaign_id & list of voter ids to dial (one voter per caller)' do
        voter_ids = Voter.order('id').limit(campaign.callers.count).pluck(:id)
        CalculateDialsJob.perform(campaign.id)

        actual = Resque.peek :dialer_worker
        expected = {'class' => 'DialerJob', 'args' => [campaign.id, voter_ids]}

        expect(actual).to(eq(expected), "Expected :dialer_worker queue to contain: #{expected}")
      end
    end

    context 'exceptions do occur' do
      before do
        allow(campaign).to receive(:number_of_voters_to_dial).and_raise("Crazyestness")
      end

      it 'handle w/ intelligence'

      it 'always deletes "dial_calculate:#{campaign.id}" redis key' do
        campaign_is_calculating_dials!(campaign)

        CalculateDialsJob.perform(campaign.id)

        expect(campaign.calculate_dialing?).to be_falsy
      end
    end
  end
end
