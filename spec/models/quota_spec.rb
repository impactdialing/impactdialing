require 'spec_helper'

describe Quota, :type => :model do

  def prorated_minutes(provider_object, minutes_per_caller)
    total          = provider_object.current_period_end - provider_object.current_period_start
    left           = provider_object.current_period_end - Time.now
    perc           = ((left/total) * 100).to_i / 100.0
    (minutes_per_caller * perc).to_i
  end

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
        expect(quota.minutes_available?).to be_truthy

        quota.minutes_used = 0
        quota.minutes_pending = 4
        expect(quota.minutes_available?).to be_truthy
      end
    end

    context 'minutes_allowed - minutes_used - minutes_pending <= 0' do
      it 'returns false' do
        quota.minutes_used = 4
        quota.minutes_pending = 6
        expect(quota.minutes_available?).to be_falsey

        quota.minutes_pending = 0
        quota.minutes_used = 10
        expect(quota.minutes_available?).to be_falsey

        quota.minutes_pending = 10
        quota.minutes_used = 0
        expect(quota.minutes_available?).to be_falsey
      end
    end
  end

  describe '#_minutes_available' do
    let(:quota) do
      Quota.new({
        minutes_allowed: 50
      })
    end

    it 'returns an Integer number of minutes available, calculated as (minutes_allowed - minutes_used - minutes_pending)' do
      expect(quota._minutes_available).to eq quota.minutes_allowed

      quota.minutes_used = 10
      expect(quota._minutes_available).to eq quota.minutes_allowed - 10

      quota.minutes_used = 39
      expect(quota._minutes_available).to eq quota.minutes_allowed - 39

      quota.minutes_pending = 10
      expect(quota._minutes_available).to eq quota.minutes_allowed - 39 - 10
    end

    it 'never returns an Integer < 0' do
      quota.minutes_used = quota.minutes_allowed
      quota.minutes_pending = 12
      expect(quota._minutes_available).to eq 0
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
      expect(quota.debit(5)).to be_truthy
    end

    it 'returns false on failure' do
      quota.account_id = nil # make it invalid
      expect(quota.debit(5)).to be_falsey
    end

    context 'minutes_available >= minutes_to_charge' do
      let(:minutes_to_charge){ 300 }
      before do
        quota.update_attributes!(minutes_allowed: 500)
        quota.debit(minutes_to_charge)
      end
      it 'adds minutes_to_charge to minutes_used' do
        expect(quota._minutes_available).to eq(quota.minutes_allowed - 300)
      end
      it 'leaves minutes_pending unchanged' do
        expect(quota.minutes_pending).to eq(quota.minutes_pending)
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
        expect(quota.minutes_used).to eq minutes_allowed
      end

      it 'adds any remaining minutes to minutes_pending' do
        expect(quota.minutes_pending).to eq expected_minutes_pending

        quota.debit(7)
        expect(quota.minutes_pending).to eq expected_minutes_pending + minutes_to_charge

        quota.debit(7)
        expect(quota.minutes_pending).to eq expected_minutes_pending + (minutes_to_charge * 2)
      end
    end
  end

  describe '#add_minutes' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end
    let(:plan) do
      double('Billing::Plan', {
        id: 'per_minute',
        minutes_per_quantity: 1,
        price_per_quantity: 0.09,
        per_minute?: true
      })
    end

    context 'adding minutes to an existing per minute plan' do

      context 'w/ some minutes not used and none pending' do
        let(:minutes_available){ 10 }
        let(:amount){ 100 }
        let(:minutes_purchased){ (amount / 9).to_i }

        before do
          quota.minutes_allowed = 20
          quota.minutes_used    = 10
          quota.minutes_pending = 0
          quota.save!
          quota.add_minutes(plan, 'per_minute', amount)
        end

        it 'sets minutes_allowed to the minutes purchased + minutes_available' do
          expect(quota.minutes_allowed).to eq minutes_purchased + minutes_available
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to eq 0
        end
        it 'sets minutes_pending to zero' do
          expect(quota.minutes_pending).to eq 0
        end
      end
      context 'w/ all minutes used' do
        let(:amount){ 200 }
        let(:minutes_purchased){ (amount / 9).to_i }

        before do
          quota.minutes_allowed = 100
          quota.minutes_used = 100
          quota.minutes_pending = 0
          quota.save!
          quota.add_minutes(plan, 'per_minute', amount)
        end

        it 'sets minutes_allowed to the minutes purchased' do
          expect(quota.minutes_allowed).to eq minutes_purchased
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to eq 0
        end
        it 'sets minutes_pending to zero' do
          expect(quota.minutes_pending).to eq 0
        end
      end
      context 'w/ all minutes used and minutes_pending' do
        context 'minutes_pending > minutes_purchased' do
          let(:minutes_pending){ 22 }
          let(:amount){ 100 }
          let(:minutes_purchased){ (amount / 9).to_i }
          before do
            quota.minutes_pending = minutes_pending
            quota.minutes_allowed = 100
            quota.minutes_used    = 100
            quota.save!
            quota.add_minutes(plan, 'per_minute', amount)
          end
          it 'sets minutes_allowed to minutes_purchased' do
            expect(quota.minutes_allowed).to eq minutes_purchased
          end
          it 'sets minutes_pending to (minutes_pending - minutes_purchased)' do
            expect(quota.minutes_pending).to eq (minutes_pending - minutes_purchased)
          end
          it 'sets minutes_used to minutes_purchased' do
            expect(quota.minutes_used).to eq minutes_purchased
          end
        end
        context 'minutes_pending < minutes_purchased' do
          let(:minutes_pending){ 20 }
          let(:amount){ 200 }
          let(:minutes_purchased){ (amount / 9).to_i }
          before do
            quota.minutes_pending = minutes_pending
            quota.minutes_allowed = 100
            quota.minutes_used    = 100
            quota.save!
            quota.add_minutes(plan, 'per_minute', amount)
          end
          it 'sets minutes_allowed to minutes_purchased' do
            expect(quota.minutes_allowed).to eq minutes_purchased
          end
          it 'sets minutes_used to minutes_pending' do
            expect(quota.minutes_used).to eq minutes_pending
          end
          it 'sets minutes_pending to 0' do
            expect(quota.minutes_pending).to eq 0
          end
        end
      end
    end
  end

  describe '#prorated_minutes' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end
    let(:basic_plan) do
      double('Billing::Plan', {
        id: 'basic',
        minutes_per_quantity: 1000,
        price_per_quantity: 49.0
      })
    end
    let(:provider_object) do
      double('ProviderSubscription', {
        quantity: 1,
        amount: 49.0,
        current_period_start: 2.weeks.ago,
        current_period_end: 2.weeks.from_now
      })
    end
    it 'returns computed minutes based on std prorate formula' do
      quantity = 1
      actual = quota.prorated_minutes(basic_plan, provider_object, quantity)
      expected = 1000 / 2
      expect(actual).to be_within(10).of(expected)
    end
  end

  describe '#renewed(plan)' do
    let(:plan){ Billing::Plans.new.find 'pro' }
    let(:quota) do
      Quota.new({
        callers_allowed: 2,
        minutes_used: 1200,
        minutes_allowed: 2350,
        minutes_pending: 12
      })
    end
    before do
      quota.renewed(plan)
    end
    it 'sets minutes_used to zero' do
      expect(quota.minutes_used).to eq 0
    end
    it 'sets minutes_pending to zero' do
      expect(quota.minutes_pending).to eq 0
    end
    it 'sets minutes_allowed to callers_allowed * plan.per_quantity (this ensures proper minutes available if e.g. customer upgrades in previous cycle and is allotted some prorated minutes)' do
      expect(quota.minutes_allowed).to eq 5000
    end
    it 'does not touch callers_allowed' do
      expect(quota.callers_allowed).to eq 2
    end
  end

  context 'changing plan features / options' do
    let(:account) do
      create(:account)
    end
    let(:quota) do
      account.quota
    end
    let(:basic_plan) do
      double('Billing::Plan', {
        id: 'basic',
        minutes_per_quantity: 1000,
        price_per_quantity: 49.0
      })
    end
    let(:provider_object) do
      double('ProviderSubscription', {
        quantity: 1,
        amount: 49.0,
        current_period_start: Time.now,
        current_period_end: 1.month.from_now
      })
    end

    describe '#change_plans_or_callers(plan, provider_object, opts)' do
      let(:opts) do
        {
          callers_allowed: 1,
          old_plan_id: 'trial'
        }
      end
      context 'Trial -> Basic' do
        before do
          quota.update_attribute(:minutes_used, 45)
          quota.reload
          expect(quota.minutes_allowed).to eq 50
          expect(quota.callers_allowed).to eq 5
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          expect(quota.callers_allowed).to eq 1
        end
        it 'sets minutes_allowed to the product of plan.minutes_per_quantity and quantity' do
          expect(quota.minutes_allowed).to eq 1000
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to eq 0
        end
      end
      context 'Pro -> Basic +1 caller (21 days into billing cycle)' do
        # This action is a no-op because we don't prorate the change
        # and the customer already paid for usage through the end of
        # the current billing cycle. Stripe will notify when downgraded
        # subscription renews.
        let(:used){ 1250 }
        let(:allowed){ 2500 }
        let(:callers){ 1 }
        before do
          allow(provider_object).to receive(:quantity){ 2 }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            callers_allowed: 1
          })
          quota.reload
          opts.merge!({
            old_plan_id: 'pro'
          })
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          expect(quota.callers_allowed).to eq provider_object.quantity
        end
        it 'does not touch minutes_allowed' do
          expect(quota.minutes_allowed).to eq allowed
        end
        it 'does not touch minutes_used' do
          expect(quota.minutes_used).to eq used
        end
      end
      context 'Basic -> Basic' do
        let(:account) do
          create(:account)
        end
        let(:quota) do
          account.quota
        end
        let(:used){ 750 }
        let(:allowed){ 1000 }
        let(:available){ 250 }
        let(:callers){ 1 }
        before do
          allow(provider_object).to receive(:current_period_start){ 7.days.ago }
          allow(provider_object).to receive(:current_period_end){ 21.days.from_now }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            minutes_pending: 0,
            callers_allowed: 1
          })
          quota.reload
          opts.merge!({
            old_plan_id: 'basic'
          })
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'sets callers_allowed to provider_object.quantity' do
          expect(quota.callers_allowed).to eq provider_object.quantity
        end
        context '+1 caller' do
          before do
            allow(provider_object).to receive(:quantity){ 2 }
            quota.change_plans_or_callers(basic_plan, provider_object, opts)
          end
          it 'sets minutes_allowed to prorated number of minutes based on billing cycle' do
            minutes_to_add           = prorated_minutes(provider_object, 1000)
            expected_minutes_allowed = minutes_to_add + allowed
            expect(quota.minutes_allowed).to be_within(10).of(expected_minutes_allowed)
          end
          it 'sets callers_allowed to provider_object.quantity' do
            expect(quota.callers_allowed).to eq provider_object.quantity
          end
        end
        context 'removing callers - verify this only changes callers_allowed because this action is not prorated. Minute quotas are updated via stripe event and so' do
          let(:used){ 1250 }
          let(:allowed){ 3000 }
          let(:callers){ 3 }
          before do
            allow(provider_object).to receive(:quantity){ 1 }
            quota.update_attributes!({
              minutes_used: used,
              minutes_allowed: allowed,
              callers_allowed: 3
            })
            quota.reload
            opts.merge!({
              old_plan_id: 'basic'
            })
            quota.change_plans_or_callers(basic_plan, provider_object, opts)
          end
          it 'sets callers_allowed to provider_object.quantity' do
            expect(quota.callers_allowed).to eq provider_object.quantity
          end
          it 'does not touch minutes_allowed' do
            expect(quota.minutes_allowed).to eq allowed
          end
          it 'does not touch minutes_used' do
            expect(quota.minutes_used).to eq used
          end
        end
      end
      context 'neither plan or number of callers changes' do
        let(:used){ 250 }
        let(:allowed){ 1000 }
        let(:callers){ 1 }
        before do
          allow(provider_object).to receive(:quantity){ callers }
          quota.update_attributes!({
            minutes_used: used,
            minutes_allowed: allowed,
            callers_allowed: callers
          })
          opts.merge!({old_plan_id: 'basic'})
          quota.change_plans_or_callers(basic_plan, provider_object, opts)
        end
        it 'does not touch minutes_allowed because this action is not prorated' do
          expect(quota.minutes_allowed).to eq allowed
        end
        it 'does not touch callers_allowed because this action is not prorated' do
          expect(quota.callers_allowed).to eq callers
        end
        it 'does not touch minutes_used because this action is not prorated' do
          expect(quota.minutes_used).to eq used
        end
      end
    end

    describe '#plan_changed!(new_plan, provider_object, opts)' do
      context 'Trial -> Basic (upgrade)' do
        let(:callers_allowed){ quota.callers_allowed + 2 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'trial'
          }
        end
        before do
          allow(provider_object).to receive(:quantity){ callers_allowed }
        end
        it 'sets `callers_allowed` to opts[:callers_allowed]' do
          quota.plan_changed!('basic', provider_object, opts)
          expect(quota.callers_allowed).to eq callers_allowed
        end
        it 'sets `minutes_allowed` to callers_allowed * plan.minutes_per_quantity' do
          quota.plan_changed!('basic', provider_object, opts)
          expect(quota.minutes_allowed).to eq callers_allowed * 1000
        end
      end
      context 'Basic -> Business (upgrade 5 days into billing cycle, caller does not change)' do
        let(:callers_allowed){ 1 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'basic',
            prorate: true
          }
        end
        before do
          allow(provider_object).to receive(:quantity){ callers_allowed }
          allow(provider_object).to receive(:current_period_start){ 5.days.ago }
          allow(provider_object).to receive(:current_period_end){ 25.days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          minutes_to_add = prorated_minutes(provider_object, 6000)
          expect(quota.minutes_allowed).to eq callers_allowed * minutes_to_add
        end
        it 'sets callers_allowed = provider_object.quantity' do
          expect(quota.callers_allowed).to eq callers_allowed
        end
        it 'sets minutes_used = 0' do
          expect(quota.minutes_used).to be_zero
        end
      end
      context 'Business -> Pro (downgrade 12 days into billing cycle, caller does not change)' do
        let(:callers_allowed){ 1 }
        let(:opts) do
          {
            callers_allowed: callers_allowed,
            old_plan_id: 'business'
          }
        end
        before do
          allow(provider_object).to receive(:current_period_start){ 12.days.ago }
          allow(provider_object).to receive(:current_period_end){ (30 - 12).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 1000,
            minutes_used: 234
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            expect(quota.callers_allowed).to eq callers_allowed
          end
          it 'does not touch minutes_allowed' do
            expect(quota.minutes_allowed).to eq 1000
          end
          it 'does not touch minutes_used' do
            expect(quota.minutes_used).to eq 234
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Business -> Pro -1 caller (downgrade & remove caller 9 days into billing cycle)' do
        let(:callers_allowed){ 3 }
        let(:opts) do
          {
            callers_allowed: callers_allowed - 1,
            old_plan_id: 'business'
          }
        end
        before do
          allow(provider_object).to receive(:quantity){ opts[:callers_allowed] }
          allow(provider_object).to receive(:current_period_start){ 9.days.ago }
          allow(provider_object).to receive(:current_period_end){ (30 - 9).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 6000,
            minutes_used: 2345
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            expect(quota.callers_allowed).to eq provider_object.quantity
          end
          it 'does not touch minutes_allowed' do
            expect(quota.minutes_allowed).to eq 6000
          end
          it 'does not touch minutes_used' do
            expect(quota.minutes_used).to eq 2345
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Business -> Pro +1 caller (downgrade & add caller 3 days into billing cycle)' do
        let(:callers_allowed){ 3 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 1,
            old_plan_id: 'business'
          }
        end
        before do
          allow(provider_object).to receive(:quantity){ opts[:callers_allowed] }
          allow(provider_object).to receive(:current_period_start){ 3.days.ago }
          allow(provider_object).to receive(:current_period_end){ (30 - 3).days.from_now }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: 6000,
            minutes_used: 2345
          })
          quota.plan_changed!('pro', provider_object, opts)
        end
        context 'immediately' do
          it 'sets callers_allowed = provider_object.quantity' do
            expect(quota.callers_allowed).to eq provider_object.quantity
          end
          it 'does not touch minutes_allowed' do
            expect(quota.minutes_allowed).to eq 6000
          end
          it 'does not touch minutes_used' do
            expect(quota.minutes_used).to eq 2345
          end
        end
        context 'eventually (once provider event is received and processed)' do
          it 'sets minutes_allowed = provider_object.quantity * 2500'
          it 'sets minutes_used = 0'
        end
      end
      context 'Pro -> Business +2 callers (upgrade & add callers 17 days into billing cycle)' do
        let(:callers_allowed){ 1 }
        let(:allowed){ 2500 }
        let(:used){ 234 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 2,
            old_plan_id: 'pro',
            prorate: true
          }
        end
        before do
          allow(provider_object).to receive(:current_period_start){ 17.days.ago }
          allow(provider_object).to receive(:current_period_end){ (30 - 17).days.from_now }
          allow(provider_object).to receive(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          expect(quota.minutes_allowed).to eq prorated_minutes(provider_object, (6000 * provider_object.quantity))
        end
        it 'sets callers_allowed = provider_object.quantity' do
          expect(quota.callers_allowed).to eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to be_zero
        end
      end
      context 'Pro -> Business -2 callers (upgrade & remove callers 13 days into billing cycle)' do
        let(:callers_allowed){ 5 }
        let(:allowed){ 2500 }
        let(:used){ 234 }
        let(:opts) do
          {
            callers_allowed: callers_allowed - 2,
            old_plan_id: 'pro',
            prorate: true
          }
        end
        before do
          allow(provider_object).to receive(:current_period_start){ 13.days.ago }
          allow(provider_object).to receive(:current_period_end){ (30 - 13).days.from_now }
          allow(provider_object).to receive(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed = prorated(provider_object.quantity * 6000)' do
          expect(quota.minutes_allowed).to eq prorated_minutes(provider_object, (6000 * provider_object.quantity))
        end
        it 'sets callers_allowed = provider_object.quantity' do
          expect(quota.callers_allowed).to eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to be_zero
        end
      end
      context 'Business -> +3 callers (29 days into billing cycle)' do
        let(:callers_allowed){ 1 }
        let(:allowed){ 6000 }
        let(:used){ 2345 }
        let(:opts) do
          {
            callers_allowed: callers_allowed + 3,
            old_plan_id: 'business',
            prorate: true
          }
        end
        before do
          allow(provider_object).to receive(:current_period_start){ 29.days.ago }
          allow(provider_object).to receive(:current_period_end){ 1.day.from_now }
          allow(provider_object).to receive(:quantity){ opts[:callers_allowed] }
          quota.update_attributes!({
            callers_allowed: callers_allowed,
            minutes_allowed: allowed,
            minutes_used: used
          })
          quota.plan_changed!('business', provider_object, opts)
        end
        it 'sets minutes_allowed += prorated(added_caller_count * 6000)' do
          expect(quota.minutes_allowed).to eq prorated_minutes(provider_object, (6000 * 3)) + allowed
        end
        it 'sets callers_allowed = provider_object.quantity' do
          expect(quota.callers_allowed).to eq provider_object.quantity
        end
        it 'sets minutes_used to zero' do
          expect(quota.minutes_used).to eq used
        end
      end
    end
  end
end
