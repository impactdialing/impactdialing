require 'rails_helper'

describe 'Benchmark: CallList::Prune::Numbers' do
  include ListHelpers
  let(:campaign){ create(:predictive) }
  let(:voter_list) do
    create(:voter_list, {
      campaign: campaign
    })
  end
  let(:households) do
    build_household_hashes(1_000, voter_list)
  end
  let(:numbers_to_delete) do
    households.keys[0..49]
  end
  before do
    import_list(voter_list, households)
  end

  subject{ CallList::Prune::Numbers.new(voter_list) }

  describe '#delete_from_sets' do
    it 'completes in < 11ms given 50 numbers to delete' do
      expect{
        subject.delete_from_sets(numbers_to_delete)
      }.to be_faster_than 0.011
    end
  end

  describe '#delete_from_hashes' do
    it 'completes in < 10ms given 50 numbers to delete' do
      expect{
        subject.delete_from_hashes(numbers_to_delete)
      }.to be_faster_than 0.01
    end
  end
end
