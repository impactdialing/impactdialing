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
      @account.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.debitable_subscription.update_attributes(minutes_utlized: 50)
      @account.debitable_subscription.debit(2.00).should be_false      
      @account.reload
      @account.minutes_utlized.should eq(50)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.debitable_subscription.update_attributes(minutes_utlized: 10)
      @account.debitable_subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.debitable_subscription.debit(2.00).should be_false
      @account.reload
      @account.minutes_utlized.should eq(10)
    end

  end

  describe "add more than 1 caller" do
    before(:each) do
      @account =  create(:account)      
      @account.reload
    end

    it "should not allow to add more than 1 caller " do
      trial = @account.subscriptions.first    
      trial.update_attributes(number_of_callers: 2).should be_false            
      trial.errors[:base].should == ["Trial account can have only 1 caller"]
    end    
  end

  describe "should upgrade from trial" do
    before(:each) do
      @account =  create(:account)      
      @account.reload
    end

    it "should upgrade to basic" do      
      customer = mock
      cards = mock
      datas = mock      
      card_info = mock
      plan = mock
      subscription = mock
      invoice = mock
      @account.current_subscription.stripe_customer_id = 123
      @account.current_subscription.save

      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      customer.should_receive(:update_subscription).with({:quantity=>1, :plan=>"ImpactDialing-Basic", :prorate=>true}).and_return(subscription)
      Stripe::Invoice.should_receive(:create).and_return(invoice)
      invoice.should_receive(:pay)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:plan).and_return(plan)            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id, "email", "Basic", 1, nil)
      Subscription.count.should eq(2)            
      @account.reload
      @account.current_subscription.type.should eq("Basic")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(1000)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.should_not be_nil
      @account.current_subscription.subscription_end_date.should_not be_nil
    end

    it "should throw support error is stripe is down" do
      Stripe::Customer.stub(:create).and_raise(Stripe::APIError)   
      subscription = Subscription.upgrade_subscription(@account.id, "email", "Basic", 1, nil) 
      Subscription.count.should eq(1)                                         
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
    end

    it "should throw error is invalid number of callers" do      
      Stripe::Customer.stub(:create).and_raise(Stripe::InvalidRequestError)   
      subscription = Subscription.upgrade_subscription(@account.id, "email", "Basic", 1, nil) 
      Subscription.count.should eq(1)                                         
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
    end

    it "should upgrade from trial to per minute" do      
      customer = mock      
      cards = mock
      datas = mock      
      card_info = mock
      plan = mock
      subscription = mock
      charge = mock
      Stripe::Customer.should_receive(:create).and_return(customer)
      customer.should_receive(:id).and_return("123")
      Stripe::Charge.should_receive(:create).and_return(charge)
      charge.should_receive(:card).and_return(card_info)      
      charge.should_receive(:customer).and_return("123")      
      card_info.should_receive(:last4).and_return("9090")
      card_info.should_receive(:exp_month).and_return("12")
      card_info.should_receive(:exp_year).and_return("2016")            
      charge.should_receive(:amount).and_return(4900)      
      subscription = Subscription.upgrade_subscription(@account.id, "email", "PerMinute", nil, 100) 
      Subscription.count.should eq(2)      
      @account.current_subscription.type.should eq("PerMinute")
      @account.current_subscription.number_of_callers.should eq(nil)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(1111)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.cc_last4.should eq("9090") 
      @account.current_subscription.exp_month.should eq("12") 
      @account.current_subscription.exp_year.should eq("2016")
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.should_not be_nil
      @account.current_subscription.subscription_end_date.should_not be_nil
    end

    it "should upgrade from trial to pro" do
      customer = mock
      cards = mock
      datas = mock      
      card_info = mock
      plan = mock
      subscription = mock
      Stripe::Customer.should_receive(:create).with(card: "token", email: "email", plan: Subscription.stripe_plan_id("Pro"), quantity: 1).and_return(customer)
      customer.should_receive(:cards).and_return(cards)
      cards.should_receive(:data).and_return(datas)
      datas.should_receive(:first).and_return(card_info)
      customer.should_receive(:id).and_return("123")
      customer.should_receive(:subscription).and_return(subscription)
      subscription.should_receive(:plan).and_return(plan)      
      card_info.should_receive(:last4).and_return("9090")
      card_info.should_receive(:exp_month).and_return("12")
      card_info.should_receive(:exp_year).and_return("2016")            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id,"email", "Pro", 1, nil)
      Subscription.count.should eq(2)      
      @account.current_subscription.type.should eq("Pro")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(2500)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.cc_last4.should eq("9090") 
      @account.current_subscription.exp_month.should eq("12") 
      @account.current_subscription.exp_year.should eq("2016")
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.to_i.should eq(DateTime.now.utc.to_i)
      @account.current_subscription.subscription_end_date.to_i.should eq((DateTime.now+30.days).utc.to_i)
    end

    it "should upgrade from trial to business" do
      customer = mock
      cards = mock
      datas = mock      
      card_info = mock
      plan = mock
      subscription = mock
      Stripe::Customer.should_receive(:create).with(card: "token", email: "email", plan: Subscription.stripe_plan_id("Business"), quantity: 1).and_return(customer)
      customer.should_receive(:cards).and_return(cards)
      cards.should_receive(:data).and_return(datas)
      datas.should_receive(:first).and_return(card_info)
      customer.should_receive(:id).and_return("123")
      customer.should_receive(:subscription).and_return(subscription)
      subscription.should_receive(:plan).and_return(plan)      
      card_info.should_receive(:last4).and_return("9090")
      card_info.should_receive(:exp_month).and_return("12")
      card_info.should_receive(:exp_year).and_return("2016")            
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id,"email", "Business", 1, nil)
      Subscription.count.should eq(2)      
      @account.current_subscription.type.should eq("Business")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(6000)      
      @account.current_subscription.stripe_customer_id.should eq("123") 
      @account.current_subscription.cc_last4.should eq("9090") 
      @account.current_subscription.exp_month.should eq("12") 
      @account.current_subscription.exp_year.should eq("2016")
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.to_i.should eq(DateTime.now.utc.to_i)
      @account.current_subscription.subscription_end_date.to_i.should eq((DateTime.now+30.days).utc.to_i)
    end
   
  end

end
