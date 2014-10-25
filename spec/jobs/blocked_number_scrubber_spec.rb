require 'spec_helper'

describe 'BlockedNumberScrubber' do
  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:voters){ create_list(:realistic_voter, 10, account: account, campaign: campaign) }
  let(:account_wide){ create(:blocked_number, account: account, number: voters.first.phone) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: voters.last.phone) }

  let(:other_account){ create(:account) }
  let(:other_campaign){ create(:power, account: account) }
  let(:other_voters){ create_list(:realistic_voter, 10, account: other_account, campaign: other_campaign) }
  let(:other_account_wide){ create(:blocked_number, account: other_account, number: other_voters.first.phone) }
  let(:other_campaign_wide){ create(:blocked_number, account: other_account, campaign: other_campaign, number: other_voters.last.phone) }

  before do
    other_voters.second.update_attributes!(phone: voters.first.phone)
    other_voters.third.update_attributes!(phone: voters.last.phone)

    BlockedNumberScrubber.perform(account_wide.id)
    BlockedNumberScrubber.perform(campaign_wide.id)
    BlockedNumberScrubber.perform(other_account_wide.id)
    BlockedNumberScrubber.perform(other_campaign_wide.id)
  end
  
  it 'marks voter blocked from account-wide list' do
    blocked = Voter.where(blocked_number_id: account_wide.id)
    expect(blocked.first.id).to eq voters.first.id
  end

  it 'marks voter blocked from campaign-wide list' do
    blocked = Voter.where(blocked_number_id: campaign_wide.id)
    expect(blocked.first.id).to eq voters.last.id
  end

  it 'does not mark voter from another account' do
    blocked = Voter.where(blocked_number_id: account_wide.id)
    expect(blocked.count).to eq 1
  end

  it 'does not mark voter from another campaign' do
    blocked = Voter.where(blocked_number_id: campaign_wide.id)
    expect(blocked.count).to eq 1
  end
end
