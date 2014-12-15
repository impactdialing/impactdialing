require 'spec_helper'

describe 'DoNotCall::Jobs::BlockedNumberDestroyed' do
  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:households){ create_list(:household, 10, :dnc, account: account, campaign: campaign) }
  let(:household_blocked_account_wide){ households.first }
  let(:household_blocked_campaign_wide){ households.last }
  let(:account_wide){ create(:blocked_number, account: account, number: household_blocked_account_wide.phone) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: household_blocked_campaign_wide.phone) }

  let(:other_account){ create(:account) }
  let(:other_campaign){ create(:power, account: account) }
  let(:other_households){ create_list(:household, 10, :dnc, account: other_account, campaign: other_campaign) }
  let(:other_account_wide){ create(:blocked_number, account: other_account, number: other_households.first.phone) }
  let(:other_campaign_wide){ create(:blocked_number, account: other_account, campaign: other_campaign, number: other_households.last.phone) }

  before do
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, account_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, campaign_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, other_account_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, other_campaign_wide.number)
  end
  
  it 'marks household unblocked from account-wide list' do
    expect( household_blocked_account_wide.reload.blocked?(:dnc) ).to be_falsey
  end

  it 'marks household unblocked from campaign-wide list' do
    expect( household_blocked_campaign_wide.reload.blocked?(:dnc) ).to be_falsey
  end

  it 'does not mark household from another account' do
    expect( other_households.second.reload.blocked?(:dnc) ).to be_truthy
  end

  it 'does not mark household from another campaign' do
    expect( other_households.third.reload.blocked?(:dnc) ).to be_truthy
  end
end