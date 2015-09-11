require 'rails_helper'

describe 'DoNotCall::Jobs::BlockedNumberCreatedOrDestroyed' do
  include ListHelpers

  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:campaign_two){ create(:preview, account: account) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households) do
    build_household_hashes(2, voter_list)
  end
  let(:phone_account_wide){ households.keys.first }
  let(:phone_campaign_wide){ households.keys.last }
  let(:account_wide){ create(:blocked_number, account: account, number: phone_account_wide) }
  let(:campaign_wide){ create(:blocked_number, account: account, campaign: campaign, number: phone_campaign_wide) }

  let(:dial_queue) do
    instance_double('CallFlow::DialQueue')
  end

  subject{ DoNotCall::Jobs::BlockedNumberCreatedOrDestroyed }

  context 'number is blocked for a campaign' do
    before do
      expect(CallFlow::DialQueue).to receive(:new).once.with(campaign){ dial_queue }
    end

    it 'tells the dial_queue to update blocked bit for the campaign' do
      expect(dial_queue).to receive(:update_blocked_property).with(phone_campaign_wide, 1)
      subject.perform(account.id, campaign.id, campaign_wide.number, 1)
    end
  end

  context 'number is blocked for an account' do
    let(:dial_queue_two) do
      instance_double('CallFlow::DialQueue')
    end

    before do
      expect(CallFlow::DialQueue).to receive(:new).once.with(campaign){ dial_queue }
      expect(CallFlow::DialQueue).to receive(:new).once.with(campaign_two){ dial_queue_two }
    end

    it 'tells the dial_queue to update blocked bit for all campaigns in the account' do
      expect(dial_queue).to receive(:update_blocked_property).with(account_wide.number, 1)
      expect(dial_queue_two).to receive(:update_blocked_property).with(account_wide.number, 1)
      subject.perform(account.id, nil, account_wide.number, 1)
    end
  end
end

