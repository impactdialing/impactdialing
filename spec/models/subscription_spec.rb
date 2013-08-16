require "spec_helper"

describe Subscription do
	describe "create customer" do
		it "should create a customer for per agent type with plan" do
			subscription = create(:basic)
			Stripe::Customer.should_receive(:create).with(card: "token", email: "email", plan: Subscription.stripe_plan_id("Basic"), quantity: 1) 
			subscription.create_customer("token", "email", "Basic", 1, nil)
		end

		it "should create a customer for per minute with amount" do
			subscription = create(:per_minute)
			customer = mock
			Stripe::Customer.should_receive(:create).with(card: "token", email: "email").and_return(customer)
			customer.should_receive(:id).and_return("123")
			Stripe::Charge.should_receive(:create).with(amount: 400, currency: "usd", customer: "123")
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

	describe "update_subscription" do

		it "should update subscription" do
			params = {}
			subscription = create(:basic, stripe_customer_id: "123")
			stripe_customer = mock
			invoice = mock
			Stripe::Customer.should_receive(:retrieve).and_return(stripe_customer)
			stripe_customer.should_receive(:update_subscription).with(params)
			Stripe::Invoice.should_receive(:create).with(customer: "123").and_return(invoice)
			invoice.should_receive(:pay)
			subscription.update_subscription(params)
		end		
	end

	describe "recharge" do
		it "should charge customer" do
			subscription = create(:per_minute, stripe_customer_id: "123")
			stripe_customer = mock
			Stripe::Customer.should_receive(:retrieve).and_return(stripe_customer)
			stripe_customer.should_receive(:id).and_return("12")
			Stripe::Charge.should_receive(:create).with(amount: "100", currency: "usd", customer: "12")
			subscription.recharge("100")
		end
	end

	describe "update subscription" do
		it "should create new customer for per agent plan" do
			account = create(:account)			
			customer = mock
			cards = mock
			datas = mock			
			card_info = mock
			account.subscription.should_receive(:create_customer_plan).and_return(customer)
			customer.should_receive(:cards).and_return(cards)
			cards.should_receive(:data).and_return(datas)
			datas.should_receive(:first).and_return(card_info)
			customer.should_receive(:id).and_return("123")
			card_info.should_receive(:last4).and_return("9090")
			card_info.should_receive(:exp_month).and_return("12")
			card_info.should_receive(:exp_year).and_return("2016")			
			account.subscription.create_subscription("token", "email", "Basic", 2, nil)
			account.reload
			account.subscription.type.should eq("Basic")
			account.subscription.number_of_callers.should eq(2)
			account.subscription.total_allowed_minutes.should eq(2000)
			account.subscription.stripe_customer_id.should eq("123")
			account.subscription.cc_last4.should eq("9090")
			account.subscription.exp_month.should eq("12")
			account.subscription.exp_year.should eq("2016")			
		end

		it "should upgrade plan for existing customer" do
			account = create(:account)			
			account.subscription.update_attributes(stripe_customer_id: "123")
			customer = mock
			cards = mock
			datas = mock			
			card_info = mock
			account.subscription.should_receive(:retrieve_customer).and_return(customer)
			account.subscription.should_receive(:update_subscription).with({plan: "ImpactDialing-Basic", quantity: 2, prorate: true})
			customer.should_receive(:cards).and_return(cards)
			cards.should_receive(:data).and_return(datas)
			datas.should_receive(:first).and_return(card_info)
			customer.should_receive(:id).and_return("123")
			card_info.should_receive(:last4).and_return("9090")
			card_info.should_receive(:exp_month).and_return("12")
			card_info.should_receive(:exp_year).and_return("2016")			
			account.subscription.upgrade_subscription("token", "email", "Basic", 2, nil)
			account.reload
			account.subscription.type.should eq("Basic")
			account.subscription.number_of_callers.should eq(2)
			account.subscription.total_allowed_minutes.should eq(2000)
			account.subscription.stripe_customer_id.should eq("123")
			account.subscription.cc_last4.should eq("9090")
			account.subscription.exp_month.should eq("12")
			account.subscription.exp_year.should eq("2016")			
		end
	end

	describe "cancel" do
		it "should cancel it" do
			account = create(:account)
			account.subscription.should_receive(:cancel_subscription)
			account.subscription.cancel
			account.reload			
			account.subscription.status.should eq(Subscription::Status::CANCELED)
			account.subscription.stripe_customer_id.should eq(nil)
			account.subscription.cc_last4.should eq(nil)
			account.subscription.exp_month.should eq(nil)
			account.subscription.exp_year.should eq(nil)

		end
	end
end  
