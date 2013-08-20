require "spec_helper"

describe Trial do

  describe "campaign_types" do
    it "should return preview and power and predictive modes" do
     Trial.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     Trial.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER], 
      [Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end

  describe "campaign" do

    before(:each) do
      @account =  create(:account)            
      @account.reload
    end
    it "should allow predictive dialing mode for trial subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save.should be_true      
    end

    it "should  allow preview dialing mode for trial subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should  allow power dialing mode for trial subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return empty" do
      Trial.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
      @account =  create(:account)
      @account.reload
    end

    it "should allow saving transfers" do
      script = build(:script, account: @account)
      script.transfers << build(:transfer, phone_number: "(203) 643-0521", transfer_type: "warm")      
      script.save!.should be_true      
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say  enabled" do
        Trial.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should not allow caller groups for callers" do
      before(:each) do
        @account =  create(:account, record_calls: false)            
        @account.reload
      end

      it "should save caller groups" do        
        caller = build(:caller, account: @account, campaign: create(:preview, account: @account))
        caller.caller_group = build(:caller_group, campaign: create(:preview, account: @account))
        caller.save.should be_true        
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        Trial.new.call_recording_enabled?.should be_true
      end
    end

    describe "it should  allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)     
        @account.reload           
      end

      it "should save" do
        @account.update_attributes(record_calls: true).should be_true        
      end
    end
  end

  describe "should debit call time" do
    before(:each) do
      @account =  create(:account, record_calls: false)   
      @account.reload   
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      @account.debitable_subscription.debit(2.00).should be_true
      @account.subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.debitable_subscription.update_attributes(minutes_utlized: 50)
      @account.debitable_subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(50)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.subscription.update_attributes(minutes_utlized: 10)
      @account.subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(10)
    end

  end

  describe "add more than 1 caller" do
    before(:each) do
      @account =  create(:account)      
      @account.reload
    end

    it "should not allow to add more than 1 caller " do
      @account.subscription.update_attributes(number_of_callers: 2).should be_false
      @account.subscription.errors[:base].should == ["Trial account can have only 1 caller"]
    end    
  end

  describe "upgrade from trial to basic" do
    before(:each) do
      @account =  create(:account, record_calls: true)      
      @account.reload      
    end

    it "should change record calls to false" do
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      @account.record_calls.should be_false
    end

    it "should convert any predictive campaigns to preview" do
      create(:predictive, account: @account)
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade(Subscription::Type::BASIC)
      @account.reload
      @account.campaigns.first.type.should eq(Campaign::Type::PREVIEW)
    end

    it "should delete any transfers in scripts" do
      script = create(:script, account: @account)
      create(:transfer, phone_number: "(203) 643-0521", transfer_type: "warm", script: script)
      script.reload
      script.transfers.size.should eq(1)
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade(Subscription::Type::BASIC)      
      @account.reload
      script.reload
      script.transfers.should eq([])
    end

    it "should add delta of minutes on upgrade" do
      customer = mock
      cards = mock
      datas = mock      
      card_info = mock
      plan = mock
      Stripe::Customer.should_receive(:create).and_return(customer)
      customer.should_receive(:cards).and_return(cards)
      customer.should_receive(:plan).and_return(plan)
      cards.should_receive(:data).and_return(datas)
      datas.should_receive(:first).and_return(card_info)
      customer.should_receive(:id).and_return("123")
      card_info.should_receive(:last4).and_return("9090")
      card_info.should_receive(:exp_month).and_return("12")
      card_info.should_receive(:exp_year).and_return("2016")      
      plan.should_receive(:amount).and_return(9900)

      Subscription.upgrade_subscription(@account.id, "token", "email", Subscription::Type::BASIC, 1, 0)            
      @account.subscriptions.count.should eq(2)
      @account.subscriptions.first.status.should eq(Subscription::Status::SUSPENDED)
      active_subscription = @account.active_subscription
      active_subscription.type.should eq(Subscription::Type::BASIC)
      active_subscription.number_of_callers.should eq(1)
      active_subscription.minutes_utlized.should eq(0)
      active_subscription.total_allowed_minutes.should eq(1000)
      active_subscription.stripe_customer_id.should eq("123")
      active_subscription.cc_last4.should eq("9090")
      active_subscription.exp_month.should eq("12")
      active_subscription.exp_year.should eq("2016")
      active_subscription.amount_paid.should eq(99.0)      
    end
  end

  describe "current_period_start" do
    it "should return current date time" do
      @account =  create(:account, record_calls: false)      
      puts Subscription.first.current_period_start
      Subscription.first.current_period_start.to_i.should eq(DateTime.now.to_i)   
    end
  end

end
