require 'rails_helper'

describe CallFlow::DialQueue::Households do
  include ListHelpers

  let(:campaign){ create(:power) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:phone_prefix){ '1234567' }

  subject{ CallFlow::DialQueue::Households.new(campaign) }

  describe 'deleting 1 full household hash' do
    let(:households) do
      h = {}
      1_000.times do |n|
        phone = "#{phone_prefix}#{'%03d' % n}"
        h.merge! build_household_hash(voter_list, true, true, true, phone)
      end
      h
    end
    before do
      import_list(voter_list, households)
    end

    it 'can achieve 666 ops/sec (1.5ms /op)' do
      # Households#purge! scans and deletes keys in batches
      # concern is to keep each delete operation under 0.001 seconds
      expect{
        redis.del "#{subject.keys[:active]}:#{phone_prefix}"
      }.to be_faster_than 0.0015
    end
  end

  describe 'deleting 100k households', data_heavy: true do
    let(:households) do
      build_household_hashes(100_000, voter_list, false, true, false)
    end
    before do
      import_list(voter_list, households)
    end

    it 'takes up to 5 seconds' do
      expect{
        subject.purge!
      }.to be_faster_than 5.0
    end
  end
end
