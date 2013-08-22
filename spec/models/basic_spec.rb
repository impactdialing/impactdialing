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
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: 5.days.ago)      
      Subscription.first.current_period_start.to_i.should eq(5.days.ago.to_i)   
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
      Subscription.first.number_of_callers.should eq(1)            
      Subscription.first.total_allowed_minutes.should eq(677)
    end

     it "should provide warning of upgrade is similar to what exist" do
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 1)            
      subscription.errors.messages.should eq({:base=>["The subscription details submitted are identical to what already exists"]})            
    end

    it "should say contact supprt if something goes wrong" do      
      expect { Stripe::Customer.retrieve(@account.current_subscription.stripe_customer_id)}.to raise_error(Stripe::APIError)                        
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
      expect { Stripe::Customer.retrieve(@account.current_subscription.stripe_customer_id)}.to raise_error(Stripe::APIError)                        
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 1)      
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})            
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

    

    it "should raise exception if new number of caller less than 1" do      
      @account.subscription.number_of_callers = 2
      @account.subscription.save           
      expect { @account.subscription.update_subscription_plan({quantity: 0, plan: @account.subscription.stripe_plan_id, prorate: false})}.to raise_error(Stripe::InvalidRequestError)            
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 0, nil)
      @account.subscription.number_of_callers.should eq(2)
      @account.subscription.errors.messages.should eq({:base=>["Please submit a valid number of callers"]})
    end

   

    it "should provide warning of upgrade is similar to what exist" do
      @account.subscription.number_of_callers = 2
      @account.subscription.save           
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::BASIC, 2, nil)
      @account.subscription.errors.messages.should eq({:base=>["The subscription details submitted are identical to what already exists"]})            
    end
  end

  describe "upgrade to per minute" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      @account.reload      
      @account.subscription.change_subscription_type(Subscription::Type::BASIC)      
      @account.subscription.upgrade(Subscription::Type::BASIC)      
      @account.reload      
    end

    it "should upgrade to per minute" do
      @account.subscription.upgrade_subscription("token", "email", Subscription::Type::PER_MINUTE, nil, 100)
      
    end
  end

  describe "upgrade from trial to basic" do
    before(:each) do
      @account =  create(:account, record_calls: true)      
      @account.reload      
    end

    it "should change record calls to false" do
      Basic.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", 
        subscription_start_date: DateTime.now)      
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
      Subscription.first.current_period_start.to_i.should eq(DateTime.now.to_i)   
    end
  end


end
