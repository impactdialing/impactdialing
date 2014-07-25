require 'spec_helper'

describe Billing::Subscription, :type => :model do
  let(:valid_settings) do
    {enabled: 1, amount: 3, trigger: 5, pending: 0}
  end
  let(:subscription){ Billing::Subscription.new }

  describe 'validations' do
    context ':plan' do
      let(:valid_plans) do
        ['trial', 'basic', 'pro', 'business', 'per_minute', 'enterprise']
      end
      before do
        allow(::Billing::Plans).to receive(:list){ valid_plans }
      end
      it 'must be present' do
        expect(subscription).to have(2).errors_on :plan
      end
      it 'must be included in ::Billing::Plans.list' do
        subscription.plan = 'borg'
        expect(subscription).to have(1).error_on :plan
        expect(subscription.errors[:plan].first).to eq "is not included in the list"
      end
    end
  end

  describe ':settings' do
    it 'is serialized as HashWithIndifferentAccess' do
      expect(subscription.settings).to be_kind_of HashWithIndifferentAccess
    end

    describe 'autorecharge_settings' do
      it 'has an :enabled key' do
        expect(subscription.autorecharge_settings).to have_key :enabled
      end
      it 'has an :amount key' do
        expect(subscription.autorecharge_settings).to have_key :amount
      end
      it 'has a :trigger key' do
        expect(subscription.autorecharge_settings).to have_key :trigger
      end
      it 'has a :pending key' do
        expect(subscription.autorecharge_settings).to have_key :pending
      end
      it 'defaults to disabled' do
        expect(subscription.autorecharge_settings[:enabled]).to eq 0
      end
    end
  end

  describe '#active?' do
    shared_examples_for 'active subscription' do
      before do
        subscription.plan = plan
      end
      it 'returns true' do
        expect(subscription.active?).to be_truthy
      end
    end
    shared_examples_for 'not active subscription' do
      before do
        subscription.plan = plan
      end
      it 'returns false' do
        expect(subscription.active?).to be_falsey
      end
    end
    ['trial', 'enterprise', 'per_minute'].each do |plan_id|
      context "#{plan_id}" do
        let(:plan){ plan_id }
        it_behaves_like 'active subscription'
      end
    end
    ['basic', 'pro', 'business'].each do |plan_id|
      context "#{plan_id}" do
        let(:plan){ plan_id }
        before do
          subscription.provider_status = 'active'
        end
        context '#provider_status == "active"' do
          it_behaves_like 'active subscription'
        end

        context '#provider_status != "active"' do
          before do
            subscription.provider_status = 'borg'
          end
          it_behaves_like 'not active subscription'
        end
      end
    end
  end

  describe '#update_autorecharge_settings!(new_settings)' do
    let(:account){ create(:account) }
    let(:subscription){ account.billing_subscription }
    it 'raises ActiveRecord::RecordInvalid if the new settings are invalid' do
      invalid_settings = {enabled: 1, amount: 0, trigger: 0}
      expect{
        subscription.update_autorecharge_settings!(invalid_settings)
      }.to raise_error ActiveRecord::RecordInvalid
    end
    it 'merges the current autorecharge hash w/ new_settings' do
      valid_settings = {'enabled' => 1, 'amount' => 1, 'trigger' => 1}
      subscription.update_autorecharge_settings!(valid_settings)
      subscription.reload
      expect(subscription.autorecharge_settings).to eq valid_settings
    end
  end

  describe '#autorecharge_amount' do
    let(:account){ create(:account) }
    let(:subscription){ account.billing_subscription }
    it 'returns an Integer' do
      subscription.update_autorecharge_settings!(valid_settings)
      expect(subscription.autorecharge_amount).to eql 3
    end
  end

  describe '#autorecharge_pending!' do
    let(:account){ create(:account) }
    let(:subscription){ account.billing_subscription }
    before do
      expect(subscription.autorecharge_pending?).to be_falsey
      subscription.autorecharge_pending!
    end
    it 'save! autorecharge_pending as 1' do
      expect(subscription.reload.autorecharge_pending).to eql 1
    end
  end

  describe '#is_renewal?(start_period, end_period)' do
    let(:subscription){ Billing::Subscription.new }
    let(:start_period){ 10.minutes.ago.to_i }
    let(:end_period){ (start_period + 1.month).to_i }

    context 'start_period != self.provider_start_period and end_period != self.provider_end_period' do
      before do
        subscription.provider_start_period = (start_period - 1.month).to_i
        subscription.provider_end_period   = (end_period - 1.month).to_i
      end

      it 'returns true' do
        expect(subscription.is_renewal?(start_period, end_period)).to be_truthy
      end
    end

    context 'start_period != self.provider_start_period or end_period != self.provider_end_period' do
      before do
        subscription.provider_start_period = start_period
        subscription.provider_end_period   = end_period
      end
      it 'returns false' do
        expect(subscription.is_renewal?(start_period, end_period)).to be_falsey
      end
    end
  end

  describe '#renewed!(start_period, end_period, status)' do
    let(:account){ create(:account) }
    let(:subscription){ account.billing_subscription }
    let(:start_period){ Time.at(10.minutes.ago) }
    let(:end_period){ Time.at(start_period + 1.month) }
    let(:status){ 'active' }

    it 'sets provider_start_period to start_period' do
      subscription.renewed!(start_period, end_period, status)
      actual = Time.at(subscription.reload.provider_start_period).utc
      expected = start_period.utc
      expect(actual).to be_within(1).of(expected)
    end
    it 'sets provider_end_period to end_period' do
      subscription.renewed!(start_period, end_period, status)
      actual = Time.at(subscription.reload.provider_end_period).utc
      expected = end_period.utc
      expect(actual).to be_within(1).of(expected)
    end
    context 'when invalid' do
      it 'raises ActiveRecord::RecordInvalid' do
        subscription.plan = nil
        expect {
          subscription.renewed!(start_period, end_period, status)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#cache_provider_status!(status)' do
    let(:account){ create(:account) }
    let(:subscription){ account.billing_subscription }
    let(:status){ 'past_due' }

    it 'sets provider_status to status' do
      subscription.cache_provider_status!(status)
      expect(subscription.provider_status).to eq status
    end
    context 'when invalid' do
      it 'raises ActiveRecord::RecordInvalid' do
        subscription.plan = nil
        expect {
          subscription.cache_provider_status!(status)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end

# ## Schema Information
#
# Table name: `billing_subscriptions`
#
# ### Columns
#
# Name                         | Type               | Attributes
# ---------------------------- | ------------------ | ---------------------------
# **`id`**                     | `integer`          | `not null, primary key`
# **`account_id`**             | `integer`          | `not null`
# **`provider_id`**            | `string(255)`      |
# **`provider_status`**        | `string(255)`      |
# **`plan`**                   | `string(255)`      | `not null`
# **`settings`**               | `text`             |
# **`created_at`**             | `datetime`         | `not null`
# **`updated_at`**             | `datetime`         | `not null`
# **`provider_start_period`**  | `integer`          |
# **`provider_end_period`**    | `integer`          |
#
# ### Indexes
#
# * `index_billing_subscriptions_on_account_id`:
#     * **`account_id`**
# * `index_billing_subscriptions_on_provider_id`:
#     * **`provider_id`**
#
