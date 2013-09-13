require "spec_helper"

describe PerMinute do
  let(:account) do
    create(:account, {
      record_calls: false
    })
  end
  let(:valid_attrs) do
    {
      account_id: account.id,
      number_of_callers: 1,
      status: Subscription::Status::UPGRADED,
      amount_paid: 25
    }
  end

  describe "campaign_types" do
    it "should return preview and power modes" do
      PerMinute.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
      PerMinute.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER],[Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end
  describe "campaign" do
    before(:each) do
      PerMinute.create!(valid_attrs)
    end
    it "should  allow predictive dialing mode for per minute subscription" do
      campaign = build(:predictive, account: account)
      campaign.save.should be_true
    end

    it "should  allow preview dialing mode for per minute subscription" do
      campaign = build(:preview, account: account)
      campaign.save.should be_true
    end

    it "should  allow power dialing mode for per minute subscription" do
      campaign = build(:power, account: account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return warm and cold transfers" do
      PerMinute.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
      PerMinute.create!(valid_attrs)
    end
    it "should  allow saving transfers" do
      script = build(:script, account: account)
      script.transfers << build(:transfer)
      script.save
      script.errors[:base].should == ["Your subscription does not allow transfering calls in this mode."]
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say enabled" do
        PerMinute.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should  allow caller groups for callers" do
      before(:each) do
        PerMinute.create!(valid_attrs)
      end
      it "should save caller with caller groups" do
        caller = build(:caller, account: account)
        caller.caller_group = build(:caller_group)
        caller.save.should be_true
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        PerMinute.new.call_recording_enabled?.should be_true
      end
    end

    describe "it should allow call recordings to be enabled" do
      before(:each) do
        PerMinute.create!(valid_attrs)
      end
      it "should all record calls" do
        account.update_attributes(record_calls: true).should be_true
      end
    end

  end

  describe "should debit call time" do
    before(:each) do
      PerMinute.create!(valid_attrs.merge({
        subscription_start_date: DateTime.now,
        subscription_end_date: DateTime.now+30.days,
        total_allowed_minutes:6000
      }))
    end

    it "should deduct from minutes used if minutes used greater than 0" do
      account.debitable_subscription.debit(2.00).should be_true
      account.debitable_subscription.minutes_utlized.should eq(2)
    end

    it "should not deduct from minutes used if minutes used greater than eq total minutes" do
      account.debitable_subscription.reload
      account.debitable_subscription.update_attributes(minutes_utlized: 6000)
      account.debitable_subscription.debit(2.00).should be_false
      account.debitable_subscription.reload
      account.debitable_subscription.minutes_utlized.should eq(6000)
    end

    it "should not deduct from minutes used if alloted minutes does not fall in subscription time range" do
      account.debitable_subscription.update_attributes(minutes_utlized: 10)
      account.debitable_subscription.update_attributes(subscription_start_date: (DateTime.now-40.days))
      account.debitable_subscription.debit(2.00).should be_false
      account.debitable_subscription.reload
      account.debitable_subscription.minutes_utlized.should eq(10)
    end
  end


  describe 'Upgrade to Per minute' do
    let(:user){ create(:user) }
    let(:basic) do
      create(:basic, {
        account: user.account
      })
    end
    let(:account_id){ user.account.id }
    let(:email){ user.email }
    let(:plan_type){ 'PerMinute' }
    let(:num_of_callers){ 2 }

    context 'add an error to amount_paid' do
      let(:per_minute) do
        PerMinute.new({
          account_id: account_id,
          number_of_callers: num_of_callers,
          amount_paid: nil
        })
      end
      after do
        per_minute.should have(1).error_on :amount_paid
        per_minute.errors[:amount_paid].first.should eq I18n.t('activerecord.errors.models.subscription.attributes.amount_paid.greater_than')
      end

      it 'when amount_paid is blank' do
        # PerMinute initialized w/ blank amount
        # assertions are in after block
      end
      it 'when amount_paid is less than zero' do
        per_minute.amount_paid = -1
      end
      it 'when amount_paid is zero' do
        per_minute.amount_paid = 0
      end
    end
  end

  describe "downgrade from per minute" do
    before(:each) do
      account.current_subscriptions.each{|x| x.update_attributes(status: Subscription::Status::SUSPENDED)}
      PerMinute.create!(valid_attrs.merge({
        stripe_customer_id: "123",
        subscription_start_date: DateTime.now-10.days,
        created_at: DateTime.now-5.minutes,
        subscription_end_date: DateTime.now+10.days
      }))
      account.reload
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
      Subscription.downgrade_subscription(account.id, "email", "Basic", 1, nil)
      Subscription.count.should eq(3)
      account.current_subscription.type.should eq("Basic")
      account.current_subscription.number_of_callers.should eq(1)
      account.current_subscription.status.should eq(Subscription::Status::DOWNGRADED)
      account.current_subscription.minutes_utlized.should eq(0)
      account.current_subscription.total_allowed_minutes.should eq(0)
      account.current_subscription.stripe_customer_id.should eq("123")
      account.current_subscription.amount_paid.should eq(0.0)
      account.current_subscription.subscription_start_date.should_not be_nil
      account.current_subscription.subscription_end_date.should_not be_nil
    end
  end

end
