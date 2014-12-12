require 'spec_helper'

describe 'ProcessRecycleBin.perform(campaign_id)' do
  include FakeCallData

  describe 'some numbers in recycle bin can be recycled' do
    let(:account){ create(:account) }
    let(:admin){ create(:user, account: account) }
    let(:campaign){ create(:power, account: account) }
    let(:caller){ create(:caller, campaign: campaign, account: account)}

    before do
      add_voters(campaign, :voter, 10)
      @dial_queue = cache_available_voters(campaign)

      10.times do |n|
        @dial_queue.next(1)
      end
      # sanity check that all were dialed
      expect(@dial_queue.available.size).to eq 0
      expect(@dial_queue.recycle_bin.size).to eq 10

      # behavior under test
      CallFlow::Jobs::ProcessRecycleBin.perform(campaign.id)
    end
    
    it 'add recyclable phone numbers to available set' do
      expect(@dial_queue.available.size).to eq 5
    end

    it 'removes recyclable phone numbers from recycle bin set' do
      expect(@dial_queue.recycle_bin.size).to eq 5
    end
  end
end