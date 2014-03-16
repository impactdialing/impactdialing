require 'spec_helper'

describe Billing::Subscription do
  let(:account){ create(:account) }
  let(:subscription){ account.billing_subscription }

  describe ':settings' do
    it 'is serialized as HashWithIndifferentAccess' do
      subscription.settings.should be_kind_of HashWithIndifferentAccess
    end

    describe 'autorecharge_settings' do
      it 'has an :enabled key' do
        subscription.autorecharge_settings.should have_key :enabled
      end
      it 'has an :amount key' do
        subscription.autorecharge_settings.should have_key :amount
      end
      it 'has a :trigger key' do
        subscription.autorecharge_settings.should have_key :trigger
      end
      it 'default to disabled' do
        subscription.autorecharge_settings[:enabled].should eq 0
      end
    end

    describe '#update_autorecharge_settings!(new_settings)' do
      it 'raises ActiveRecord::RecordInvalid if the new settings are invalid' do
        invalid_settings = {enabled: 1, amount: 0, trigger: 0}
        expect{
          subscription.update_autorecharge_settings!(invalid_settings)
        }.to raise_error ActiveRecord::RecordInvalid
      end
      it 'replaces the current autorecharge hash w/ new_settings' do
        valid_settings = {'enabled' => 1, 'amount' => 1, 'trigger' => 1}
        subscription.update_autorecharge_settings!(valid_settings)
        subscription.reload
        subscription.autorecharge_settings.should eq valid_settings
      end
    end

    describe '#autorecharge_amount' do
      it 'returns an Integer' do
        settings = {enabled: 1, amount: 3, trigger: 5}
        subscription.update_autorecharge_settings!(settings)
        subscription.autorecharge_amount.should eql 3
      end
    end
  end
end
