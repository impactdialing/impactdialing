require 'spec_helper'

describe 'CallFlow::DialQueue::DoNotCall' do
  let(:account){ create(:account) }
  let(:admin){ create(:user, account: account) }
  let(:campaign){ create(:power, account: account) }
  let!(:account_dnc) do
    create_list(:bare_blocked_number, 10, account: account)
  end
  let!(:campaign_dnc) do
    create_list(:bare_blocked_number, 10, account: account, campaign: campaign)
  end

  subject{ CallFlow::DialQueue::DoNotCall.new(campaign) }

  describe 'caching' do
    before do
      subject.cache!
    end

    it 'caches a set of account-wide do not call numbers' do
      expect(
        subject.account_dnc - account.blocked_numbers.where('campaign_id IS NULL').pluck(:number)
      ).to eq []
    end
    it 'caches a set of campaign-specific do not call numbers' do
      expect(
        subject.campaign_dnc - account.blocked_numbers.where(campaign_id: campaign.id).pluck(:number)
      ).to eq []
    end
  end

  describe 'fetching' do
    it 'returns the union of account-wide & campaign-specific do not call number sets' do
      account_wide = account.blocked_numbers.where('campaign_id IS NULL').pluck(:number)
      campaign_specific = account.blocked_numbers.where(campaign_id: campaign.id).pluck(:number)
      expect(
        subject.all - (account_wide + campaign_specific)
      ).to eq []
    end
  end

  it 'might be better as a sorted set?'
end
