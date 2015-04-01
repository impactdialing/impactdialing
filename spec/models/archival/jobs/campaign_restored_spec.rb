require 'rails_helper'

describe 'Archival::Jobs::CampaignRestored' do
  subject{ Archival::Jobs::CampaignRestored }

  let(:account){ create(:account) }
  let(:script){ create(:script, account: account) }
  let(:campaign){ create(:bare_power, account: account, script: script, active: false) }
  let!(:voters){ create_list(:voter, 5, campaign: campaign) }
  let!(:disabled_voters){ create_list(:voter, 5, campaign: campaign, enabled: []) }

  before do
    Redis.new.flushall
  end

  after do
    Redis.new.flushall
  end

  it 'caches all enabled voters in the dial queue' do
    subject.perform(campaign.id)
    expect(campaign.dial_queue.available.size).to eq 5
  end

  it 'does not cache any disabled voters' do
    subject.perform(campaign.id)
    disabled_voters.each do |voter|
      expect(campaign.dial_queue.households.missing?(voter.household.phone)).to be_truthy
    end
  end

  it 'requeues itself on TERM' do
    allow(Campaign).to receive(:find){ campaign }
    allow(campaign).to receive(:all_voters){ raise Resque::TermException, 'TERM' }
    subject.perform(campaign.id)
    expect(resque_jobs(:background_worker)).to include({
      'class' => subject.to_s,
      'args' => [campaign.id]
    })
  end
end