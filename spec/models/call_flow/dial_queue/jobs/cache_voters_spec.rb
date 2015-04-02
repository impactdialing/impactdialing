require 'rails_helper'

describe 'CacheVoters.perform(campaign_id, voter_ids, enabled)' do
  subject{ CallFlow::DialQueue::Jobs::CacheVoters }
  let(:campaign){ create(:power) }
  before do
    create_list(:voter, 10, campaign: campaign)
  end

  after do
    Redis.new.flushall
    allow(CallFlow::DialQueue).to receive(:new).and_call_original
  end

  context 'enabled.to_i > 0' do
    it 'adds voters to dial queue cache' do
      subject.perform(campaign.id, campaign.all_voters.pluck(:id), '1')
      expect(campaign.dial_queue.available.size).to eq 10
    end
    it 'requeues itself on TERM' do
      allow(CallFlow::DialQueue).to receive(:new){ raise Resque::TermException, 'TERM' }
      subject.perform(campaign.id, campaign.all_voters.pluck(:id), '1')
      expect(resque_jobs(:dial_queue)).to include({
        'class' => subject.to_s,
        'args' => [campaign.id, campaign.all_voters.pluck(:id), '1']
      })
    end
  end

  context 'enabled.to_i <= 0' do
    before do
      subject.perform(campaign.id, campaign.all_voters.pluck(:id), '1')
    end
    it 'removes voters from dial queue cache' do
      subject.perform(campaign.id, campaign.all_voters.pluck(:id), '0')
      expect(campaign.dial_queue.available.size).to eq 0
    end
    it 'requeues itself on TERM' do
      allow(CallFlow::DialQueue).to receive(:new){ raise Resque::TermException, 'TERM' }
      subject.perform(campaign.id, campaign.all_voters.pluck(:id), '0')
      expect(resque_jobs(:dial_queue)).to include({
        'class' => subject.to_s,
        'args' => [campaign.id, campaign.all_voters.pluck(:id), '0']
      })
    end
  end
end
