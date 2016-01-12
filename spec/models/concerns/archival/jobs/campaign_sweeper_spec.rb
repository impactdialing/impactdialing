require 'rails_helper'

describe 'Archival::Jobs::CampaignSweeper' do
  include ListHelpers

  subject{ Archival::Jobs::CampaignSweeper }
  let(:account){ create(:account) }
  let(:script){ create(:script, account: account) }
  let(:inactive_campaign) do
    create(:bare_preview, {
      account: account,
      script: script,
      active: true,
      created_at: 100.days.ago,
      updated_at: 91.days.ago
    })
  end
  let(:list_of_inactive) do
    create(:voter_list, campaign: inactive_campaign)
  end
  let(:inactive_households) do
    build_household_hashes(5, list_of_inactive)
  end
  let(:active_campaign) do
    create(:bare_predictive, {account: account, script: script, active: true})
  end
  let(:list_of_active) do
    create(:voter_list, campaign: active_campaign)
  end
  let(:active_households) do
    build_household_hashes(5, list_of_active)
  end
  let!(:caller1){ create(:caller, account: account, campaign: inactive_campaign) }
  let!(:caller2){ create(:caller, account: account, campaign: active_campaign) }
  before do
    create(:bare_call_attempt, {campaign: inactive_campaign, created_at: 91.days.ago})
    create(:bare_call_attempt, {campaign: active_campaign, created_at: 89.days.ago})
    import_list(list_of_inactive, inactive_households, 'inactive')
    import_list(list_of_active, active_households)
  end

  it 'archives campaigns where the last call attempt is older than 90 days' do
    subject.perform
    expect(Campaign.archived.count).to eq 1
    expect(Campaign.archived.first).to eq inactive_campaign
    expect([:resque, :general]).to have_queued(CallFlow::DialQueue::Jobs::Purge).with(inactive_campaign.id)
    expect([:resque, :general]).to have_queued(Archival::Jobs::CampaignArchived).with(inactive_campaign.id)
  end

  it 'does nothing with campaigns where the last call attempt is younger than 90 days' do
    subject.perform
    expect(Campaign.active.count).to eq 1
    expect(Campaign.active.first).to eq active_campaign
    expect(resque_jobs(:general)).to_not include({
      'class' => 'CallFlow::DialQueue::Jobs::Purge',
      'args' => [active_campaign.id]
    })
    expect(resque_jobs(:general)).to_not include({
      'class' => 'Archival::Jobs::CampaignArchived',
      'args' => [active_campaign.id]
    })
  end

  it 'does nothing with campaigns that were updated in the last 90 days' do
    inactive_campaign.updated_at = 89.days.ago
    inactive_campaign.save!
    subject.perform

    expect(Campaign.active.count).to eq 2
    expect(Campaign.active.to_a).to include inactive_campaign
    expect(resque_jobs(:general)).to_not include({
      'class' => 'CallFlow::DialQueue::Jobs::Purge',
      'args' => [inactive_campaign.id]
    })
    expect(resque_jobs(:general)).to_not include({
      'class' => 'Archival::Jobs::CampaignArchived',
      'args' => [inactive_campaign.id]
    })
  end
end
