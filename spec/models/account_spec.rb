require "spec_helper"

describe Account, :type => :model do
  it {is_expected.to have_many :caller_groups}
  it {is_expected.to have_one :billing_subscription}

  context "A New Account is created" do
    let(:valid_attrs) do
      {}
    end
    let(:account) do
      Account.create!(valid_attrs)
    end
    it 'assigns an API key' do
      expect(account.api_key).not_to be_blank
    end
    it 'creates a billing_subscription w/ plan of Trial' do
      expect(account.billing_subscription.plan).to eq 'trial'
    end
    it 'creates account_quotas w/ allowed minutes of 50 and number of callers at 5' do
      expect(account.quota.minutes_allowed).to eq 50
      expect(account.quota.callers_allowed).to eq 5
    end
  end

  describe '#minutes_available?' do
    it 'delegates to Quota' do
      account = Account.create!
      expect(account.quota).to receive(:minutes_available?)
      account.minutes_available?
    end
  end

  it "can toggle the call_recording setting" do
    account = create(:account, :record_calls => true)
    expect(account.record_calls?).to be_truthy
    account.toggle_call_recording!
    expect(account.record_calls?).to be_falsey
    account.toggle_call_recording!
    expect(account.record_calls?).to be_truthy
  end

  it "lists all custom fields" do
    account = create(:account)
    field1 = create(:custom_voter_field, :name => "field1", :account => account)
    field2 = create(:custom_voter_field, :name => "field2", :account => account)
    field3 = create(:custom_voter_field, :name => "field3", :account => account)
    expect(account.custom_fields).to eq([field1, field2, field3])
  end
end
