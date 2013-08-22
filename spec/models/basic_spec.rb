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
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)      
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
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)      
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
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)      
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
        Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)      
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
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)      
    end

    xit "should deduct from minutes used if minutes used greater than 0" do
      @account.subscription.debit(2.00).should be_true
      @account.subscription.minutes_utlized.should eq(2)
    end

    xit "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.subscription.reload      
      @account.subscription.update_attributes(minutes_utlized: 1000)
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload      
      @account.subscription.minutes_utlized.should eq(1000)
    end

    xit "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.subscription.update_attributes(minutes_utlized: 10)
      @account.subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.subscription.debit(2.00).should be_false
      @account.subscription.reload
      @account.subscription.minutes_utlized.should eq(10)
    end

  end

  describe "current_period_start" do
    it "should return current date time" do
      @account =  create(:account, record_calls: false)                  
      date = 5.days.ago
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: date)      
      Subscription.first.current_period_start.to_i.should eq(date.to_i)   
    end
  end

  describe "add caller" do
    before(:each) do
      @account =  create(:account)      
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes)      
      @account.reload
    end

    it "should give active number of callers" do
      Subscription.active_number_of_callers(@account.id).should eq(1)
      Basic.create!(account_id: @account.id, number_of_callers: 2, status: Subscription::Status::UPGRADED)      
      Subscription.active_number_of_callers(@account.id).should eq(3)
    end

    it "should add caller to subscription" do                  
      customer = mock
      invoice = mock      
      Stripe::Customer.should_receive(:retrieve).with(@account.current_subscription.stripe_customer_id).and_return(customer)
      customer.should_receive(:update_subscription).with({quantity: 2, plan: @account.current_subscription.stripe_plan_id, prorate: true})
      Stripe::Invoice.should_receive(:create).with(customer: @account.current_subscription.stripe_customer_id).and_return(invoice)
      invoice.should_receive(:pay)      
      Subscription.modify_callers_to_existing_subscription(@account.id, 2)      
      Subscription.count.should eq(3)
      Subscription.active_number_of_callers(@account.id).should eq(2)      
      Subscription.first.type.should eq(Subscription::Type::BASIC)
      Subscription.first.status.should eq(Subscription::Status::CALLERS_ADDED)
      Subscription.first.number_of_callers.should eq(1)            
      Subscription.first.total_allowed_minutes.should eq(677)
    end

     it "should provide warning of upgrade is similar to what exist" do
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 1)            
      subscription.errors.messages.should eq({:base=>["The subscription details submitted are identical to what already exists"]})            
    end

    it "should say contact supprt if something goes wrong" do      
      Stripe::Customer.stub(:retrieve).and_raise(Stripe::APIError)                              
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 3)      
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
    end

  end

  describe "remove caller" do
     before(:each) do
      @account =  create(:account)      
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Basic.create!(account_id: @account.id, number_of_callers: 2, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes)      
      @account.reload
    end

    it "should decrement number of callers" do
      customer = mock
      Stripe::Customer.should_receive(:retrieve).with(@account.current_subscription.stripe_customer_id).and_return(customer)
      customer.should_receive(:update_subscription).with({quantity: 1, plan: @account.current_subscription.stripe_plan_id, prorate: false})
      Subscription.modify_callers_to_existing_subscription(@account.id, 1)      
      Subscription.count.should eq(3)
      Subscription.active_number_of_callers(@account.id).should eq(1)      
      Subscription.first.type.should eq(Subscription::Type::BASIC)
      Subscription.first.number_of_callers.should eq(-1)            
      Subscription.first.total_allowed_minutes.should eq(0)
    end

    it "should say contact support if something goes wrong" do   
      Stripe::Customer.stub(:retrieve).and_raise(Stripe::APIError)                                       
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 1)      
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
    end

    it "should raise invalid request if number of caller to decrement leaves no callers in the subscription" do
      Stripe::Customer.stub(:retrieve).and_raise(Stripe::InvalidRequestError)                                       
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 0)      
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
    end

  end

  
  describe "upgrade from basic" do
    before(:each) do
      @account =  create(:account)      
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes)      
      @account.reload
    end

     it "should upgrade  to pro" do
      customer = mock
      plan = mock
      subscription = mock
      invoice = mock
      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      Stripe::Invoice.should_receive(:create).and_return(invoice)
      invoice.should_receive(:pay) 
      customer.should_receive(:update_subscription).and_return(subscription)            
      subscription.should_receive(:plan).and_return(plan)            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id, "token", "email", "Pro", 1, nil)
      Subscription.count.should eq(3)      
      @account.current_subscription.type.should eq("Pro")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(1693)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.to_i.should_not be_nil
      @account.current_subscription.subscription_end_date.to_i.should_not be_nil
    end

    it "should upgrade  to business" do
      customer = mock
      plan = mock
      subscription = mock
      invoice = mock
      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      Stripe::Invoice.should_receive(:create).and_return(invoice)
      invoice.should_receive(:pay) 
      customer.should_receive(:update_subscription).and_return(subscription)            
      subscription.should_receive(:plan).and_return(plan)            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id, "token", "email", "Business", 1, nil)
      Subscription.count.should eq(3)      
      @account.current_subscription.type.should eq("Business")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(4064)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.to_i.should eq(DateTime.now.utc.to_i)
      @account.current_subscription.subscription_end_date.to_i.should eq((DateTime.now+30.days).utc.to_i)
    end

    it "should upgrade  to per minute" do
      customer = mock
      plan = mock
      subscription = mock
      invoice = mock
      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      Stripe::Invoice.should_receive(:create).and_return(invoice)
      invoice.should_receive(:pay) 
      customer.should_receive(:update_subscription).and_return(subscription)            
      subscription.should_receive(:plan).and_return(plan)            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id, "token", "email", "PerMinute", nil, 200)
      Subscription.count.should eq(3)      
      @account.current_subscription.type.should eq("PerMinute")
      @account.current_subscription.number_of_callers.should eq(nil)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(2222)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.to_i.should eq(DateTime.now.utc.to_i)
      @account.current_subscription.subscription_end_date.to_i.should eq((DateTime.now+30.days).utc.to_i)
    end
   
  end

  
  describe "upgrade from trial to basic" do
    before(:each) do
      @account =  create(:account, record_calls: true)      
      create(:predictive, account: @account)      
      @account.subscriptions.update_all(status: Subscription::Status::SUSPENDED)       
      @account.reload      
      
    end

    it "should change record calls to false" do      
      @subscription = Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+30.days)      
      @subscription.subscribe
      @account.reload
      @account.record_calls.should be_false
    end

    it "should convert any predictive campaigns to preview" do      
      @subscription = Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+30.days)      
      @subscription.subscribe
      @account.reload
      @account.campaigns.first.type.should eq(Campaign::Type::PREVIEW)
    end

    it "should delete any transfers in scripts" do
      script = create(:script, account: @account)
      create(:transfer, phone_number: "(203) 643-0521", transfer_type: "warm", script: script)
      script.reload
      script.transfers.size.should eq(1)
      @subscription = Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+30.days)      
      @subscription.subscribe      
      @account.reload
      script.reload
      script.transfers.should eq([])
    end    
  end

  describe "current_period_start" do
    it "should return current date time" do
      @account =  create(:account, record_calls: false)            
      Subscription.first.current_period_start.to_i.should eq(DateTime.now.to_i)   
    end
  end


end
