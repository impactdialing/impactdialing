require 'spec_helper'

describe 'CalculateDialsJob' do
  include FakeCallData

  def make_abandon_rate_acceptable(campaign)
    create_list(:bare_call_attempt, 10, :completed, {
      campaign: campaign
    })
    create_list(:bare_call_attempt, 1, :abandoned, {
      campaign: campaign
    })
  end
  def campaign_is_calculating_dials!(campaign)
    campaign.set_calculate_dialing
    expect(campaign.calculate_dialing?).to be_truthy
  end

  let(:admin) do
    create(:user)
  end
  let(:campaign) do
    create_campaign_with_script(:bare_predictive, admin.account).last
  end

  describe '.perform(campaign_id)' do
    let(:dial_queue) do
      CallFlow::DialQueue.new(campaign)
    end

    before do
      add_voters(campaign, :realistic_voter, 25)
      add_callers(campaign, 5)
      dial_queue.prepend(:available)
    end

    after do
      Resque.remove_queue :dialer_worker
    end

    shared_examples 'all calculate dial jobs' do
      it 'removes "dial_calculate:#{campaign_id}" key from Redis, such that Predictive#calculate_dialing? returns false (flag exists to help prevent queueing multiple CalculateDialsJob from DialerLoop' do
        campaign_is_calculating_dials!(campaign)

        CalculateDialsJob.perform(campaign.id)

        expect(campaign.calculate_dialing?).to be_falsy
      end
    end

    shared_examples 'very early returning calculate dial jobs' do
      it 'does not calculate how many dials should be attempted' do
        expect(campaign).to_not receive(:number_of_voters_to_dial)
        expect(Campaign).to receive(:find).with(campaign.id){ campaign }
        CalculateDialsJob.perform(campaign.id)
      end
    end

    context 'predictive campaign not fit to dial' do
      context 'account funds not available' do
        before do
          admin.account.quota.update_attributes(minutes_allowed: 0)
        end

        it_behaves_like 'very early returning calculate dial jobs'
      end

      context 'outside calling hours' do
        before do
          campaign.update_attributes(start_time: Time.now.hour - 2, end_time: Time.now.hour - 1)
        end

        it_behaves_like 'very early returning calculate dial jobs'
      end
    end

    context 'one or more dials will be made' do
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

        expect(actual).to(eq(expected), [
          "Expected :dialer_worker queue to contain: #{expected}",
          "Got: #{actual}"
        ].join("\n"))
      end

      it_behaves_like 'all calculate dial jobs'
    end

    context 'no dials will be made' do
      before do
        campaign.callers.each do |caller|
          create(:bare_caller_session, :not_available, :webui, {
            campaign: campaign, caller: caller
          })
        end
      end
      context 'calculated voters to dial is zero or less' do
        before do
          available_caller_session = create(:bare_caller_session, :available, :webui, {
            campaign: campaign, caller: campaign.callers.first
          })
          create(:bare_call_attempt, :ready, {
            campaign: campaign, caller: campaign.callers.first, caller_session: available_caller_session
          })
          make_abandon_rate_acceptable(campaign)
        end

        it_behaves_like 'all calculate dial jobs'

        it 'returns early' do
          CalculateDialsJob.perform(campaign.id)
          resque_actual = Resque.peek :dialer_worker
          resque_expected = nil
          sidekiq_actual = Resque.peek :call_flow
          sidekiq_expected = nil

          expect(resque_actual).to eq resque_expected
          expect(sidekiq_actual).to eq sidekiq_expected
        end
      end

      context 'no voters returned from load attempt' do
        before do
          create_list(:bare_caller_session, 5, :available, :webui, {
            campaign: campaign, caller: campaign.callers.first
          })

          dial_queue = CallFlow::DialQueue.new(campaign)
          dial_queue.next(Voter.count)
          Voter.update_all({last_call_attempt_time: 20.minutes.ago})
        end

        it_behaves_like 'all calculate dial jobs'

        it 'queues CampaignOutOfNumbersJob for all available callers' do
          expect(campaign.caller_sessions.available.count).to eq 5
          expect(CallFlow::DialQueue.new(campaign).size(:available)).to be_zero

          CalculateDialsJob.perform(campaign.id)

          actual = Resque.peek(:call_flow, 0, 10)

          expect(actual.size).to eq 5

          actual.each do |job|
            expect(job['class']).to eq 'CampaignOutOfNumbersJob'
          end
        end
      end
    end

    context 'exceptions do occur' do
      before do
        allow(campaign).to receive(:number_of_voters_to_dial).and_raise("Crazyestness")
      end

      it 'handle w/ intelligence'
      
      it_behaves_like 'all calculate dial jobs'
    end
  end
end
