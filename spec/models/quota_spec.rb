require 'spec_helper'

describe Quota do
  describe '#minutes_available?' do
    let(:quota) do
      Quota.new({
        minutes_allowed: 10
      })
    end
    context 'minutes_allowed - minutes_used - minutes_pending > 0' do
      it 'returns true' do
        quota.minutes_used = 4
        quota.minutes_pending = 0
        quota.minutes_available?.should be_true

        quota.minutes_used = 0
        quota.minutes_pending = 4
        quota.minutes_available?.should be_true
      end
    end

    context 'minutes_allowed - minutes_used - minutes_pending <= 0' do
      it 'returns false' do
        quota.minutes_used = 4
        quota.minutes_pending = 6
        quota.minutes_available?.should be_false

        quota.minutes_pending = 0
        quota.minutes_used = 10
        quota.minutes_available?.should be_false

        quota.minutes_pending = 10
        quota.minutes_used = 0
        quota.minutes_available?.should be_false
      end
    end
  end

  describe '#minutes_available' do
    let(:quota) do
      Quota.new({
        minutes_allowed: 50
      })
    end

    it 'returns an Integer number of minutes available, calculated as (minutes_allowed - minutes_used - minutes_pending)' do
      quota.minutes_available.should eq quota.minutes_allowed

      quota.minutes_used = 10
      quota.minutes_available.should eq quota.minutes_allowed - 10

      quota.minutes_used = 39
      quota.minutes_available.should eq quota.minutes_allowed - 39

      quota.minutes_pending = 10
      quota.minutes_available.should eq quota.minutes_allowed - 39 - 10
    end

    it 'never returns an Integer < 0' do
      quota.minutes_used = quota.minutes_allowed
      quota.minutes_pending = 12
      quota.minutes_available.should eq 0
    end
  end

  describe '#debit(minutes_to_charge)' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end

    it 'returns true on success' do
      quota.debit(5).should be_true
    end

    it 'returns false on failure' do
      quota.account_id = nil # make it invalid
      quota.debit(5).should be_false
    end

    context 'minutes_available >= minutes_to_charge' do
      let(:minutes_to_charge){ 300 }
      before do
        quota.update_attributes!(minutes_allowed: 500)
        quota.debit(minutes_to_charge)
      end
      it 'adds minutes_to_charge to minutes_used' do
        quota.minutes_available.should eq(quota.minutes_allowed - 300)
      end
      it 'leaves minutes_pending unchanged' do
        quota.minutes_pending.should eq(quota.minutes_pending)
      end
    end

    context 'minutes_available < minutes_to_charge' do
      let(:minutes_to_charge){ 7 }
      let(:minutes_used){ 498 }
      let(:minutes_allowed){ 500 }
      let(:expected_minutes_pending) do
        minutes_to_charge - (minutes_allowed - minutes_used)
      end
      before do
        quota.update_attributes!({
          minutes_allowed: minutes_allowed,
          minutes_used: minutes_used
        })
        quota.debit(minutes_to_charge)
      end

      it 'adds (minutes_to_charge - minutes_available) to minutes_used' do
        quota.minutes_used.should eq minutes_allowed
      end

      it 'adds any remaining minutes to minutes_pending' do
        quota.minutes_pending.should eq expected_minutes_pending

        quota.debit(7)
        quota.minutes_pending.should eq expected_minutes_pending + minutes_to_charge

        quota.debit(7)
        quota.minutes_pending.should eq expected_minutes_pending + (minutes_to_charge * 2)
      end
    end
  end
end
