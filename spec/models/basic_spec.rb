require "spec_helper"

describe Basic do
  describe "campaign_types" do
    it "should return preview and power modes" do
     Basic.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     Basic.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER]])
    end
  end

  describe "campaign" do

    before(:each) do
      @account =  create(:account)
      @account.reload
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end
    it "should not allow predictive dialing mode for basic subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save
      campaign.errors[:base].should == ['Your subscription does not allow this mode of Dialing.']
    end

    it "should  allow preview dialing mode for basic subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should  allow power dialing mode for basic subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return empty" do
      Basic.new.transfer_types.should eq([])
    end
  end

  describe "transfers" do
    before(:each) do
      @account =  create(:account)
      @account.reload
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end
    it "should not all saving transfers" do
      script = build(:script, account: @account)
      script.transfers << build(:transfer)
      script.save
      script.errors[:base].should == ["Your subscription does not allow transfering calls in this mode."]
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say not enabled" do
        Basic.new.caller_groups_enabled?.should be_false
      end
    end

    describe "it should not allow caller groups for callers" do
      before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end
      it "should throw validation error" do
        campaign =   create(:preview, account: @account)
        caller = build(:caller, account: @account, campaign: campaign)
        caller.caller_group = build(:caller_group, account: @account, campaign: campaign)
        caller.save
        caller.errors[:base].should == ["Your subscription does not allow managing caller groups."]
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say not enabled" do
        Basic.new.call_recording_enabled?.should be_false
      end
    end

    describe "it should not allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload
        @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
        @account.subscription.upgrade("Basic")
        @account.reload
      end
      it "should throw validation error" do
        @account.update_attributes(record_calls: true)
        @account.errors[:base].should == ["Your subscription does not allow call recordings."]
      end
    end
  end

  describe "should debit call time" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      @account.subscription.debit(2.00).should be_true
      @account.subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.subscription.reload      
      @account.subscription.update_attributes(minutes_utlized: 1000)
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload      
      @account.subscription.minutes_utlized.should eq(1000)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.subscription.update_attributes(minutes_utlized: 10)
      @account.subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(10)
    end

  end

  describe "add caller" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end

    it "should add caller to subscription" do
      @account.subscription.reload
      @account.subscription.number_of_callers.should eq(1)
      @account.subscription.add_callers(1)
      @account.subscription.number_of_callers.should eq(2)
    end

    it "should add caller and delta minutes to subscription" do  
      @account.subscription.update_attributes(subscription_start_date: (DateTime.now-10.days), minutes_utlized: 1000)    
      @account.subscription.add_callers(1)
      @account.subscription.total_allowed_minutes.should eq(1677)
    end
  end

  describe "remove caller" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end

    it "should decrement number of callers" do
      @account.subscription.reload      
      @account.subscription.add_callers(1)
      @account.subscription.number_of_callers.should eq(2)
      @account.subscription.remove_callers(1)
      @account.subscription.number_of_callers.should eq(1)
    end
  end

  describe "renew" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade("Basic")
      @account.reload
    end

    it "should change subscription date" do
      @account.subscription.renew
      @account.subscription.subscription_start_date.utc.to_s.should eq(DateTime.now.utc.to_s)
    end

    it "should set minutes utlized to 0" do
      @account.subscription.renew
      @account.subscription.minutes_utlized.should eq(0)
    end

    it "should calculate total minutes alloted" do
      @account.subscription.update_attributes(number_of_callers: 2)
      @account.subscription.renew
      @account.subscription.total_allowed_minutes.should eq(2000)
    end
  end

  describe "update callers" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade(Subscription::Type::BASIC)      
      @account.reload      
    end

    it "should remove callers if new number of caller less than existing" do      
      @account.subscription.number_of_callers = 2
      @account.subscription.save            
      @account.subscription.should_receive(:update_subscription_plan).with({quantity: 1, plan: @account.subscription.stripe_plan_id, prorate: false})
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 1, nil)
      @account.subscription.number_of_callers.should eq(1)
    end

    it "should raise exception if new number of caller less than 1" do      
      @account.subscription.number_of_callers = 2
      @account.subscription.save           
      expect { @account.subscription.update_subscription_plan({quantity: 0, plan: @account.subscription.stripe_plan_id, prorate: false})}.to raise_error(Stripe::InvalidRequestError)            
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 0, nil)
      @account.subscription.number_of_callers.should eq(2)
      @account.subscription.errors.messages.should eq({:base=>["Please submit a valid number of callers"]})
    end

    it "should add callers" do      
      @account.subscription.number_of_callers = 2
      @account.subscription.save           
      @account.subscription.should_receive(:update_subscription_plan).with({quantity: 3, plan: @account.subscription.stripe_plan_id, prorate: true})
      @account.subscription.should_receive(:invoice_customer)
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 3, nil)
      @account.subscription.number_of_callers.should eq(3)      
    end

    it "should provide warning of upgrade is similar to what exist" do
      @account.subscription.number_of_callers = 2
      @account.subscription.save           
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 2, nil)
      @account.subscription.errors.messages.should eq({:base=>["The subscription details submitted are identical to what already exists"]})            
    end
  end

  describe "upgrade to per minute" do
    it "should upgrade to per minute" do
      
    end
  end


end
