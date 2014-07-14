require "spec_helper"

describe Account do
  it {should have_many :caller_groups}
  it {should have_one :billing_subscription}

  context "A New Account is created" do
    let(:valid_attrs) do
      {}
    end
    let(:account) do
      Account.create!(valid_attrs)
    end
    it 'assigns an API key' do
      account.api_key.should_not be_blank
    end
    it 'creates a billing_subscription w/ plan of Trial' do
      account.billing_subscription.plan.should eq 'trial'
    end
    it 'creates account_quotas w/ allowed minutes of 50 and number of callers at 5' do
      account.quota.minutes_allowed.should eq 50
      account.quota.callers_allowed.should eq 5
    end
  end

  describe '#minutes_available?' do
    it 'delegates to Quota' do
      account = Account.create!
      account.quota.should_receive(:minutes_available?)
      account.minutes_available?
    end
  end

  it "can toggle the call_recording setting" do
    account = create(:account, :record_calls => true)
    account.record_calls?.should be_truthy
    account.toggle_call_recording!
    account.record_calls?.should be_falsey
    account.toggle_call_recording!
    account.record_calls?.should be_truthy
  end

  it "lists all custom fields" do
    account = create(:account)
    field1 = create(:custom_voter_field, :name => "field1", :account => account)
    field2 = create(:custom_voter_field, :name => "field2", :account => account)
    field3 = create(:custom_voter_field, :name => "field3", :account => account)
    account.custom_fields.should == [field1, field2, field3]
  end
end
