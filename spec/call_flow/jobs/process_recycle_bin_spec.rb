require 'spec_helper'

describe 'ProcessRecycleBin.perform(campaign_id)' do
  include FakeCallData

  describe 'some numbers in recycle bin can be recycled' do
    let(:account){ create(:account) }
    let(:admin){ create(:user, account: account) }
    let(:campaign){ create(:power, account: account) }
    let(:caller){ create(:caller, campaign: campaign, account: account)}

    before do
      add_voters(campaign, :realistic_voter, 10)
      @dial_queue = cache_available_voters(campaign)

      10.times do |n|
        voter_ids = @dial_queue.next(1)
        voter     = Voter.find(voter_ids).first
        if (n+1) < 6
          attach_call_attempt(:past_recycle_time_busy_call_attempt, voter, caller)
        else
          attach_call_attempt(:completed_call_attempt, voter, caller)
        end
      end
      # sanity check that all were dialed
      expect(@dial_queue.available.size).to eq 0
      expect(@dial_queue.recycle_bin.size).to eq 10

      # behavior under test
      CallFlow::Jobs::ProcessRecycleBin.perform(campaign.id)
    end
    
    it 'add recyclable phone numbers' do
      expect(@dial_queue.available.size).to eq 5
    end

    it 'removes recyclable phone numbers from recycle bin set' do
      expect(@dial_queue.recycle_bin.size).to eq 5
    end
  end
end