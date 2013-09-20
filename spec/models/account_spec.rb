require "spec_helper"

describe Account do
  it {should have_many :caller_groups}

  it "returns the activated status as the paid flag" do
    create(:account, :activated => true).paid?.should be_true
    create(:account, :activated => false).paid?.should be_false
  end

  it "can toggle the call_recording setting" do
    account = create(:account, :record_calls => true)
    account.record_calls?.should be_true
    account.toggle_call_recording!
    account.record_calls?.should be_false
    account.toggle_call_recording!
    account.record_calls?.should be_true
  end

  it "lists all custom fields" do
    account = create(:account)
    field1 = create(:custom_voter_field, :name => "field1", :account => account)
    field2 = create(:custom_voter_field, :name => "field2", :account => account)
    field3 = create(:custom_voter_field, :name => "field3", :account => account)
    account.custom_fields.should == [field1, field2, field3]
  end

  describe '#zero_all_subscription_minutes' do
    let(:account){ create(:account) }

    before do
      account.available_minutes.should eq 50
    end

    it 'aborts and returns subscription obj when it fails to save' do
      subscription = double(:subscription, {
        status: 'Upgraded',
        subscription_start_date: 10.days.ago,
        subscription_end_date: 10.days.from_now,
        total_allowed_minutes: 100,
        minutes_utlized: 0,
        zero_minutes!: false
      })
      account.stub(:subscriptions){ [subscription] }
      actual = account.zero_all_subscription_minutes!
      actual.should eq subscription
    end

    it 'returns true when all subscriptions save' do
      actual = account.zero_all_subscription_minutes!
      actual.class.should eq TrueClass
    end

    context 'trial minutes' do
      it 'are zeroed out' do
        account.zero_all_subscription_minutes!
        account.available_minutes.should eq 0
      end
    end

    context 'basic minutes' do
      let(:basic) do
        create(:basic, {
          account: account,
          number_of_callers: 2,
          subscription_start_date: 10.days.ago,
          subscription_end_date: 10.days.from_now
        })
      end
      before do
        basic.total_allowed_minutes = 500
        basic.save!
        account.subscriptions.reload
        account.available_minutes.should eq 550
      end
      it 'are zeroed out' do
        account.zero_all_subscription_minutes!
        account.available_minutes.should eq 0
      end
    end

    context 'per minute minutes' do
      let(:per_minute) do
        create(:per_minute, {
          account: account,
          number_of_callers: 2,
          subscription_start_date: 10.days.ago,
          subscription_end_date: 10.days.from_now
        })
      end
      before do
        per_minute.total_allowed_minutes = 1000
        per_minute.save!
        account.subscriptions.reload
        account.available_minutes.should eq 1050
      end
      it 'are zeroed out' do
        account.zero_all_subscription_minutes!
        account.available_minutes.should eq 0
      end
    end
  end

  describe '#upgraded_to_enterprise' do
    let(:account){ build(:account) }
    before do
      account.activated = false
      account.card_verified = false
      account.subscription_name = 'Per Agent'

      account.upgraded_to_enterprise
      account.reload
    end
    it 'updates :activated to true' do
      account.activated.should be_true
    end

    it 'updates :card_verified to true' do
      account.card_verified.should be_true
    end

    it 'updates :subscription_name to "Manual"' do
      account.subscription_name.should eq 'Manual'
    end
  end

end
