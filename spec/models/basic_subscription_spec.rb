require "spec_helper"

describe BasicSubscription do
  describe "campaign_types" do
    it "should return preview and power modes" do
     BasicSubscription.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     BasicSubscription.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER]])
    end
  end

  describe "campaign" do
    let(:account) { create(:account) }
    before(:each) do
      account.subscription.upgrade(1,"Basic")
    end
    it "should not allow predictive dialing mode for basic subscription" do
      campaign = build(:predictive, account: account)
      campaign.save
      campaign.errors[:base].should == ['Your subscription does not allow this mode of Dialing.']
    end

    it "should not allow preview dialing mode for basic subscription" do
      campaign = build(:preview, account: account)
      campaign.save.should be_true
    end

    it "should not allow power dialing mode for basic subscription" do
      campaign = build(:power, account: account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return empty" do
      BasicSubscription.new.transfer_types.should eq([])
    end
  end

  describe "transfers" do
    let(:account) { create(:account, subscription_name: Account::Subscription_Type::BASIC, record_calls: false) }
    it "should not all saving transfers" do
      script = build(:script, account: account)
      script.transfers << build(:transfer)
      script.save
      script.errors[:base].should == ["Your subscription does not allow transfering calls in this mode."]
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say not enabled" do
        BasicSubscription.new.caller_groups_enabled?.should be_false
      end
    end

    describe "it should not allow caller groups for callers" do
      let(:account) { create(:account, subscription_name: Account::Subscription_Type::BASIC, record_calls: false) }
      it "should throw validation error" do
        caller = build(:caller, account: account)
        caller.caller_group = build(:caller_group)
        caller.save
        caller.errors[:base].should == ["Your subscription does not allow managing caller groups."]
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say not enabled" do
        BasicSubscription.new.call_recording_enabled?.should be_false
      end
    end

    describe "it should not allow call recordings to be enabled" do
      let(:account) { create(:account, subscription_name: Account::Subscription_Type::BASIC, record_calls: false) }
      it "should throw validation error" do
        account.update_attributes(record_calls: true)
        account.errors[:base].should == ["Your subscription does not allow call recordings."]
      end
    end
  end

end
