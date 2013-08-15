module SubscriptionProvider

	module ClassMethods
  end

  module InstanceMethods

		def create_customer(token, email, plan_type, number_of_callers, amount)
			if [Subscription::Type::TRIAL, Subscription::Type::BASIC, Subscription::Type::PRO, Subscription::Type::BUSINESS].include?(plan_type)
				Stripe::Customer.create(card: token, email: email, plan: Subscription.stripe_plan_id(plan_type), quantity: number_of_callers)
			else
				customer = Stripe::Customer.create(card: token, email: email)
				Stripe::Charge.create(amount: amount, currency: "usd", customer: customer.id)
				customer
			end
		end

		def retrieve_customer
			Stripe::Customer.retrieve(stripe_customer_id)
		end

		def update_subscription(params)			
			stripe_customer = retrieve_customer
			stripe_customer.update_subscription(params)
			invoice_customer
		end

		def recharge(amount)
			customer = retrieve_customer
			Stripe::Charge.create(amount: amount, currency: "usd", customer: customer.id)
		end

		def invoice_customer
			invoice = Stripe::Invoice.create(customer: stripe_customer_id)
			invoice.pay
		end

		def cancel_subscription
			if per_agent?
				stripe_customer = Stripe::Customer.retrieve(stripe_customer_id)
		  	stripe_customer.cancel_subscription
		  end
		end
	end

	def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

	
end