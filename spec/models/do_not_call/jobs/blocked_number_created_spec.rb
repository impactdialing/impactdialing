require 'spec_helper'

describe 'DoNotCall::Jobs::BlockedNumberCreated' do
  include FakeCallData

  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let!(:voters){ create_list(:voter, 10, account: account, campaign: campaign) }
  let(:households){ voters.map(&:household) }
  let(:household_blocked_account_wide){ households.first }
  let(:household_blocked_campaign_wide){ households.last }
  let(:account_wide){ create(:blocked_number, account: account, number: household_blocked_account_wide.phone) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: household_blocked_campaign_wide.phone) }

  let(:other_account){ create(:account) }
  let(:other_campaign){ create(:power, account: other_account) }
  let!(:other_voters){ create_list(:voter, 10, account: other_account, campaign: other_campaign) }
  let(:other_households){ other_voters.map(&:household) }
  let(:other_account_wide){ create(:blocked_number, account: other_account, number: other_households.first.phone) }
  let(:other_campaign_wide){ create(:blocked_number, account: other_account, campaign: other_campaign, number: other_households.last.phone) }

  before do
    cache_available_voters(campaign)
    cache_available_voters(other_campaign)
    DoNotCall::Jobs::BlockedNumberCreated.perform(account_wide.id)
    DoNotCall::Jobs::BlockedNumberCreated.perform(campaign_wide.id)
    DoNotCall::Jobs::BlockedNumberCreated.perform(other_account_wide.id)
    DoNotCall::Jobs::BlockedNumberCreated.perform(other_campaign_wide.id)
  end
  
  it 'marks household blocked from account-wide list' do
    expect( household_blocked_account_wide.reload.blocked?(:dnc) ).to be_truthy
  end
  it 'removes blocked household from dial queue' do
    dial_queue = CallFlow::DialQueue.new(campaign)
    expect( dial_queue.available.missing?(account_wide.number) ).to be_truthy
    expect( dial_queue.recycle_bin.missing?(account_wide.number) ).to be_truthy
    expect( dial_queue.households.missing?(account_wide.number) ).to be_truthy
  end

  it 'marks household blocked from campaign-wide list' do
    expect( household_blocked_campaign_wide.reload.blocked?(:dnc) ).to be_truthy
  end
  it 'removes blocked household from dial queue' do
    dial_queue = CallFlow::DialQueue.new(campaign)
    expect( dial_queue.available.missing?(campaign_wide.number) ).to be_truthy
    expect( dial_queue.recycle_bin.missing?(campaign_wide.number) ).to be_truthy
    expect( dial_queue.households.missing?(campaign_wide.number) ).to be_truthy
  end

  it 'does not mark household from another account' do
    expect( other_households.second.reload.blocked?(:dnc) ).to be_falsey
  end

  it 'does not mark household from another campaign' do
    expect( other_households.third.reload.blocked?(:dnc) ).to be_falsey
  end
end
