require "spec_helper"

describe Pro do
    describe "campaign_types" do
    it "should return preview and power modes" do
     Pro.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     Pro.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER],[Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end
  describe "campaign" do
    before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload
        @account.subscription.upgrade("Pro")
        @account.reload
    end

    it "should  allow predictive dialing mode for pro subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save.should be_true
    end

    it "should not allow preview dialing mode for pro subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should not allow power dialing mode for pro subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return warm and cold transfers" do
      Pro.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload
        @account.subscription.upgrade("Pro")
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
      it "should say enabled" do
        Pro.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should  allow caller groups for callers" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload
        @account.subscription.upgrade("Pro")
        @account.reload
      end      
      it "should save caller with caller groups" do
        caller = build(:caller, account: @account)
        caller.caller_group = build(:caller_group)
        caller.save.should be_true
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        Pro.new.call_recording_enabled?.should be_false
      end
    end

    describe "it should allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        @account.reload
        @account.subscription.upgrade("Pro")
        @account.reload
      end     

      it "should all record calls" do
        @account.update_attributes(record_calls: true)
        @account.errors[:base].should == ["Your subscription does not allow call recordings."]
      end
    end
  end

  describe "should debit call time" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload
      @account.subscription.upgrade("Pro")
      @account.reload
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      @account.subscription.debit(2.00).should be_true
      @account.subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.subscription.reload            
      @account.subscription.update_attributes!(minutes_utlized: 2500)
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload      
      @account.subscription.minutes_utlized.should eq(2500)
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
      @account.subscription.upgrade("Pro")
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
      @account.subscription.total_allowed_minutes.should eq(4193)
    end
  end

  describe "remove caller" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.upgrade("Pro")
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
      @account.subscription.upgrade("Pro")
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
      @account.subscription.total_allowed_minutes.should eq(5000)
    end


  end




end
