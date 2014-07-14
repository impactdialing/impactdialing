require 'spec_helper'

describe Report::SelectiveDateRange do
  let(:from_pool){ [nil, 10.days.ago, nil, 2.days.ago] }
  let(:to_pool){ [nil,4.days.ago,nil,1.day.ago] }

  describe '.new(from_date_pool, to_date_pool)' do
    it 'uses the first non-nil element from each pool' do
      date_range = Report::SelectiveDateRange.new(from_pool, to_pool)
      expect(date_range.from_before_normalize).to eq from_pool[1]
    end

    it 'to_date_pool can be empty, in which case it will default to current datetime' do
      Timecop.freeze(Time.now) do
        date_range = Report::SelectiveDateRange.new(from_pool, [])
        expect(date_range.to_before_normalize).to eq Time.now
      end
    end

    it 'parses any String elements (e.g. mm/dd/yy) to Date objects' do
      from_pool[0]  = '02/17/1982'
      expected_from = Time.utc(1982, 2, 17, 0, 0, 0)
      date_range    = Report::SelectiveDateRange.new(from_pool)

      expect(date_range.from).to eq expected_from
    end
  end

  context 'given a from_date_pool with at least one non-nil element and an empty to_date_pool' do
    describe '#from' do
      it 'returns normalized copy the first non-nil date element to midnight of the same day UTC' do
        date_range = Report::SelectiveDateRange.new(from_pool)
        expected   = 10.days.ago.beginning_of_day.utc

        expect(date_range.from).to eq expected
      end
    end
    describe '#to' do
      it 'returns the current datetime, normalized to 11:59PM UTC' do
        Timecop.freeze(Time.now) do
          date_range    = Report::SelectiveDateRange.new(from_pool)
          expected_to   = Time.now.utc.end_of_day
          expect(date_range.to).to eq expected_to
        end
      end
    end
  end

  context 'given an empty from_date_pool' do
    it 'raises ArgumentError'
  end

  context 'given first non-nil element of pool is datetime object' do
    let(:campaign){ create(:power, time_zone: "Pacific Time (US & Canada)") }

    it 'normalizes to include records from the start of the day' do
      campaign.created_at = Time.now.end_of_day - 1.minute
      campaign.save!

      pool       = [campaign.created_at]
      date_range = Report::SelectiveDateRange.new(pool)
      actual     = Campaign.where('created_at > ?', date_range.from).first

      expect(actual).to eq campaign
    end

    it 'normalizes to include records from the beginning of the day' do
      campaign.created_at = Time.now.beginning_of_day + 1.minute
      campaign.save!

      pool       = [campaign.created_at]
      date_range = Report::SelectiveDateRange.new(pool)
      actual     = Campaign.where('created_at < ?', date_range.to).first

      expect(actual).to eq campaign
    end
  end
end
