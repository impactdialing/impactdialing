require 'rails_helper'

describe 'CallFlow::Jobs::PruneHouseholds' do
  subject{ CallFlow::Jobs::PruneHouseholds }

  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:voters){ create_list(:voter, 10, campaign: campaign) }
  let(:empty_households){ create_list(:household, 6, campaign: campaign) }

  before do
    Redis.new.flushall
  end

  context 'some households have no associated voters' do
    before do
      changing_voters = []
      empty_households.each do |house|
        changing_voters << create(:voter, household: house, campaign: campaign)
      end
      campaign.dial_queue.cache_all(voters + changing_voters)
      dial_queue = campaign.dial_queue
      empty_households.each do |household|
        expect(dial_queue.available.missing?(household.phone)).to be_falsey
        expect(dial_queue.households.missing?(household.phone)).to be_falsey
      end
      changing_voters.each do |voter|
        voter.update_attribute(:household_id, create(:household, campaign: campaign).id)
      end
    end

    context 'dial queue exists for the campaign' do
      it 'removes the household from the dial queue' do
        subject.perform(campaign.id, *campaign.household_ids)
        dial_queue = campaign.dial_queue
        empty_households.each do |household|
          expect(dial_queue.available.missing?(household.phone)).to be_truthy
          expect(dial_queue.households.missing?(household.phone)).to be_truthy
        end
      end
    end

    context 'no calls have been placed to the household' do
      it 'destroys the household record' do
        empty_household_ids = empty_households.map(&:id)
        subject.perform(campaign.id, *campaign.household_ids)
        expect(Household.where(id: empty_household_ids).count).to be_zero
      end

      it 'does not destroy households with associated voters' do
        pre_count     = campaign.households.count
        household_ids = campaign.households.where('id NOT IN (?)', empty_households.map(&:id))
        subject.perform(campaign.id, *household_ids)
        expect(Household.where(id: household_ids).count).to(eq(pre_count - empty_households.size))
      end
    end

    context 'calls have been placed to the household' do
      before do
        empty_households.each do |household|
          create(:call_attempt, household: household, campaign: campaign)
        end
      end
      it 'does not destroy the household record' do
        pre_count = campaign.households.count
        subject.perform(campaign.id, *campaign.household_ids)
        expect(campaign.households.count).to eq pre_count
      end
    end
  end

  it 'requeues itself on TERM' do
    voters # create voter records
    allow(campaign).to receive(:households){ raise Resque::TermException, 'TERM' }
    allow(Campaign).to receive(:find){ campaign }
    subject.perform(campaign.id, *campaign.household_ids)
    expect(resque_jobs(:data_migrations)).to include({
      'class' => subject.to_s,
      'args' => [campaign.id, *campaign.household_ids]
    })
  end
end
