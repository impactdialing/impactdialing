require 'spec_helper'

describe 'Archival::Jobs::CampaignRestored' do
  subject{ Archival::Jobs::CampaignRestored }

  let(:account){ create(:account) }
  let(:script){ create(:script, account: account) }
  let(:campaign){ create(:bare_power, account: account, script: script, active: false) }
  let!(:voters){ create_list(:voter, 5, campaign: campaign) }
  let!(:disabled_voters){ create_list(:voter, 5, campaign: campaign, enabled: []) }

  before do
    subject.perform(campaign.id)
  end

  it 'caches all enabled voters in the dial queue' do
    expect(campaign.dial_queue.available.size).to eq 5
  end

  it 'does not cache any disabled voters' do
    disabled_voters.each do |voter|
      expect(campaign.dial_queue.households.missing?(voter.household.phone)).to be_truthy
    end
  end
end