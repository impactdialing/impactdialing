require "spec_helper"

describe Pro do

  before do
    Timecop.freeze(Time.local(2013, 8, 10, 12))
  end
  after do
    Timecop.return
  end

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
        Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
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
        Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
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
        Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
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
        Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
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
      Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED,
        subscription_start_date: DateTime.now, subscription_end_date: DateTime.now+30.days, total_allowed_minutes:2500)
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      @account.debitable_subscription.debit(2.00).should be_true
      @account.debitable_subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      @account.debitable_subscription.reload
      @account.debitable_subscription.update_attributes!(minutes_utlized: 2500)
      @account.debitable_subscription.debit(2.00).should be_false
      @account.debitable_subscription.reload
      @account.debitable_subscription.minutes_utlized.should eq(2500)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      @account.debitable_subscription.update_attributes(minutes_utlized: 10)
      @account.debitable_subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      @account.debitable_subscription.debit(2.00).should be_false
      @account.debitable_subscription.reload
      @account.debitable_subscription.minutes_utlized.should eq(10)
    end

  end

   describe "add caller" do
    before(:each) do
      @account =  create(:account)
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes)
      @account.reload
    end

    it "should give active number of callers" do
      Subscription.active_number_of_callers(@account.id).should eq(1)
      Pro.create!(account_id: @account.id, number_of_callers: 2, status: Subscription::Status::UPGRADED)
      Subscription.active_number_of_callers(@account.id).should eq(3)
    end

    it "should add caller to subscription" do
      customer = double
      invoice = double
      Stripe::Customer.should_receive(:retrieve).with(@account.current_subscription.stripe_customer_id).and_return(customer)
      customer.should_receive(:update_subscription).with({quantity: 2, plan: @account.current_subscription.stripe_plan_id, prorate: true})
      Stripe::Invoice.should_receive(:create).with(customer: @account.current_subscription.stripe_customer_id).and_return(invoice)
      invoice.should_receive(:pay)
      Subscription.modify_callers_to_existing_subscription(@account.id, 2)
      Subscription.count.should eq(3)
      Subscription.active_number_of_callers(@account.id).should eq(2)
      Subscription.first.type.should eq(Subscription::Type::PRO)
      Subscription.first.status.should eq(Subscription::Status::CALLERS_ADDED)
      Subscription.first.number_of_callers.should eq(1)
      Subscription.first.total_allowed_minutes.should eq(1693)
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
      Pro.create!(account_id: @account.id, number_of_callers: 2, status: Subscription::Status::UPGRADED, stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes)
      @account.reload
    end

    it "should decrement number of callers" do
      customer = double
      Stripe::Customer.should_receive(:retrieve).with(@account.current_subscription.stripe_customer_id).and_return(customer)
      customer.should_receive(:update_subscription).with({quantity: 1, plan: @account.current_subscription.stripe_plan_id, prorate: false})
      Subscription.modify_callers_to_existing_subscription(@account.id, 1)
      Subscription.count.should eq(3)
      Subscription.active_number_of_callers(@account.id).should eq(1)
      Subscription.first.type.should eq(Subscription::Type::PRO)
      Subscription.first.number_of_callers.should eq(-1)
      Subscription.first.total_allowed_minutes.should eq(0)
    end

    it "should say contact support if something goes wrong" do
      Stripe::Customer.stub(:retrieve).and_raise(Stripe::APIError)
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 1)
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})
    end

    it "should raise invalid request if number of caller to decrement leaves no callers in the subscription" do
      Stripe::Customer.stub(:retrieve)
      subscription = Subscription.modify_callers_to_existing_subscription(@account.id, 0)
      subscription.errors.messages.should eq({:base=>["Something went wrong with your upgrade. Kindly contact support"]})
    end

  end

  describe "upgrade from pro" do
    before(:each) do
      @account =  create(:account)
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED, stripe_customer_id: "123",
        subscription_start_date: DateTime.now-10.days, created_at: DateTime.now-5.minutes, subscription_end_date: DateTime.now+10.days)
      @account.reload
    end

    it "should upgrade  to business" do
      customer = double
      plan = double
      subscription = double
      invoice = double
      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      Stripe::Invoice.should_receive(:create).and_return(invoice)
      invoice.should_receive(:pay)
      customer.should_receive(:update_subscription).and_return(subscription)
      subscription.should_receive(:plan).and_return(plan)
      plan.should_receive(:amount).and_return(4900)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.upgrade_subscription(@account.id, "email", "Business", 1, nil)
      Subscription.count.should eq(3)
      @account.current_subscription.type.should eq("Business")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::UPGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(4064)
      @account.current_subscription.stripe_customer_id.should eq("123")
      @account.current_subscription.amount_paid.should eq(49.0)
      @account.current_subscription.subscription_start_date.should_not be_nil
      @account.current_subscription.subscription_end_date.should_not be_nil
    end

    it "should upgrade  to per minute" do
      customer = double
      card_info = double
      subscription = double
      charge = double
      Stripe::Customer.should_receive(:retrieve).and_return(customer)
      customer.should_receive(:id).and_return("123")
      Stripe::Charge.should_receive(:create).and_return(charge)
      charge.should_receive(:card).and_return(card_info)
      charge.should_receive(:customer).and_return("123")
      card_info.should_receive(:last4).and_return("9090")
      card_info.should_receive(:exp_month).and_return("12")
      card_info.should_receive(:exp_year).and_return("2016")
      charge.should_receive(:amount).and_return(4900)
      subscription = Subscription.upgrade_subscription(@account.id, "email", "PerMinute", nil, 100)
      Subscription.count.should eq(3)
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

  end

  describe "downgrade from pro" do
    before(:each) do
      @account =  create(:account)
      @account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      Pro.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED,
        stripe_customer_id: "123", subscription_start_date: DateTime.now-10.days,
        created_at: DateTime.now-5.minutes, subscription_end_date: DateTime.now+10.days)
      @account.reload
    end

    it "should downgrade to basic" do
      customer = double
      plan = double
      subscription = double
      Stripe::Customer.should_receive(:retrieve).with("123").and_return(customer)
      customer.should_receive(:update_subscription).and_return(subscription)
      subscription.should_receive(:plan).and_return(plan)
      plan.should_receive(:amount).and_return(0000)
      subscription.should_receive(:customer).and_return("123")
      subscription.should_receive(:current_period_start).and_return(DateTime.now.to_i)
      subscription.should_receive(:current_period_end).and_return((DateTime.now+30.days).to_i)
      Subscription.downgrade_subscription(@account.id, "token", "email", "Basic", 1, nil)
      Subscription.count.should eq(3)
      @account.current_subscription.type.should eq("Basic")
      @account.current_subscription.number_of_callers.should eq(1)
      @account.current_subscription.status.should eq(Subscription::Status::DOWNGRADED)
      @account.current_subscription.minutes_utlized.should eq(0)
      @account.current_subscription.total_allowed_minutes.should eq(0)
      @account.current_subscription.stripe_customer_id.should eq("123")
      @account.current_subscription.amount_paid.should eq(0.0)
      @account.current_subscription.subscription_start_date.should_not be_nil
      @account.current_subscription.subscription_end_date.should_not be_nil
    end
  end
end
