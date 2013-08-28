require "spec_helper"

describe Subscription do
	describe "create customer" do
		xit "should create a customer for per agent type with plan" do
			subscription = create(:basic)
			Stripe::Customer.should_receive(:create).with(card: "token", email: "email", plan: Subscription.stripe_plan_id("Basic"), quantity: 1) 
			subscription.create_customer("token", "email", "Basic", 1, nil)
		end

		xit "should create a customer for per minute with amount" do
			subscription = create(:per_minute)
			customer = mock
			Stripe::Customer.should_receive(:create).with(card: "token", email: "email").and_return(customer)
			customer.should_receive(:id).and_return("123")
			Stripe::Charge.should_receive(:create).with(amount: 40000, currency: "usd", customer: "123")
			subscription.create_customer("token", "email", nil, nil, 400)
		end
	end

	describe "retrieve_customer" do
		it "should fetch customer from stripe" do
			subscription = create(:per_minute, stripe_customer_id: "123")
			Stripe::Customer.should_receive(:retrieve) 
			subscription.retrieve_customer
		end
	end

	describe "cancel_subscription" do
		it "should cancel subscription for per agent type" do
			subscription = create(:basic)
			customer = mock
			Stripe::Customer.should_receive(:retrieve).and_return(customer)
			customer.should_receive(:cancel_subscription)		  
			subscription.cancel_subscription
		end

		it "should not cancel subscription for non per agent type" do
			subscription = create(:per_minute)			
			Stripe::Customer.should_not_receive(:retrieve)			
			subscription.cancel_subscription
		end
	end

	describe "invoice customer" do
		it "should create customer invoice and pay it" do
			subscription = create(:basic, stripe_customer_id: "123")
			invoice = mock
			Stripe::Invoice.should_receive(:create).with(customer: "123").and_return(invoice)
			invoice.should_receive(:pay)
			subscription.invoice_customer
		end
	end

	

	describe "recharge" do
		it "should charge customer" do
			subscription = build(:per_minute, stripe_customer_id: "123", amount_paid: 100)
			stripe_customer = mock
			Stripe::Customer.should_receive(:retrieve).and_return(stripe_customer)
			stripe_customer.should_receive(:id).and_return("12")
			Stripe::Charge.should_receive(:create).with(amount: 10000, currency: "usd", customer: "12")
			subscription.recharge()
		end
	end

	describe "update subscription" do
		
		
	end

	
	describe "cancel" do
		it "should cancel it" do
			account = create(:account)
			Account.should_receive(:find).and_return(account)
			account.current_subscription.should_receive(:cancel_subscription)
			Subscription.cancel(account.id)				
			Subscription.first.status.should eq(Subscription::Status::CANCELED)
			Subscription.first.stripe_customer_id.should eq(nil)
			Subscription.first.cc_last4.should eq(nil)
			Subscription.first.exp_month.should eq(nil)
			Subscription.first.exp_year.should eq(nil)

		end
	end
end  
