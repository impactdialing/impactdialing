require 'spec_helper'

describe 'DoNotCall::Jobs::BlockedNumberDestroyed' do
  include FakeCallData

  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let!(:voters){ create_list(:voter, 10, account: account, campaign: campaign) }
  let!(:households){ voters.map{|v| v.household.update_attributes(blocked: Household.bitmask_for_blocked(:dnc), account_id: v.account_id, campaign_id: v.campaign_id); v.household} }
  let(:household_blocked_account_wide){ households.first }
  let(:household_blocked_campaign_wide){ households.last }
  let(:account_wide){ create(:blocked_number, account: account, number: household_blocked_account_wide.phone) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: household_blocked_campaign_wide.phone) }

  let(:other_account){ create(:account) }
  let(:other_campaign){ create(:power, account: other_account) }
  let!(:other_voters){ create_list(:voter, 10, account: other_account, campaign: other_campaign) }
  let!(:other_households){ voters.map{|v| v.household.update_attributes(blocked: Household.bitmask_for_blocked(:dnc)); v.household} }
  let(:other_account_wide){ create(:blocked_number, account: other_account, number: other_households.first.phone) }
  let(:other_campaign_wide){ create(:blocked_number, account: other_account, campaign: other_campaign, number: other_households.last.phone) }

  before do
    cache_available_voters(campaign)
    cache_available_voters(other_campaign)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, account_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, campaign_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, other_account_wide.number)
    DoNotCall::Jobs::BlockedNumberDestroyed.perform(account.id, campaign.id, other_campaign_wide.number)
  end
  
  it 'marks household unblocked from account-wide list' do
    expect( household_blocked_account_wide.reload.blocked?(:dnc) ).to be_falsey
  end
  it 'adds blocked household to dial queue' do
    dial_queue = CallFlow::DialQueue.new(campaign)
    expect( dial_queue.available.missing?(account_wide.number) ).to be_falsey
    expect( dial_queue.households.missing?(account_wide.number) ).to be_falsey
  end

  it 'marks household unblocked from campaign-wide list' do
    expect( household_blocked_campaign_wide.reload.blocked?(:dnc) ).to be_falsey
  end
  it 'adds blocked household to dial queue' do
    dial_queue = CallFlow::DialQueue.new(campaign)
    expect( dial_queue.available.missing?(campaign_wide.number) ).to be_falsey
    expect( dial_queue.households.missing?(campaign_wide.number) ).to be_falsey
  end

  it 'does not mark household from another account' do
    expect( other_households.second.reload.blocked?(:dnc) ).to be_truthy
  end

  it 'does not mark household from another campaign' do
    expect( other_households.third.reload.blocked?(:dnc) ).to be_truthy
  end
end