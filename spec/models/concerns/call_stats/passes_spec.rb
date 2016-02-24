require 'rails_helper'

describe CallStats::Passes do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:households){ build_household_hashes(20, voter_list) }

  subject{ CallStats::Passes.new(campaign) }

  before do
    import_list(voter_list, households)
    household = nil

    campaign.dial_queue.available.all[0..5].each do |phone|
      household = create(:household, campaign: campaign, phone: phone)
      create(:call_attempt, campaign: campaign, household: household)
      campaign.dial_queue.households.find(phone)[:leads].each do |lead|
        create(:voter, {
          campaign: campaign,
          household: household,
          first_name: lead[:first_name],
          last_name: lead[:last_name]
        })
      end
      campaign.dial_queue.dialed_number_persisted(phone, nil)
    end
    create(:call_attempt, campaign: campaign, household: household)
    campaign.dial_queue.dialed_number_persisted(household.phone, nil)
  end

  describe '#current_pass' do
    it 'returns an integer representing most dials to a household' do
      expect(subject.current_pass).to eq 2
    end
  end

  describe '#households_dialed' do
    it 'returns a hash of household ids => call attempt counts' do
      expected_counts = campaign.call_attempts.group(:household_id).count
      expect(subject.households_dialed).to eq expected_counts
    end
  end

  describe '#households_dialed_n_times(n)' do
    it 'returns an integer count of households dialed at least n times' do
      expect(subject.households_dialed_n_times(1)).to eq campaign.households.count
      expect(subject.households_dialed_n_times(2)).to eq 1
    end
  end
end
